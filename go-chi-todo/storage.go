package main

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"log/slog"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const ossRDBMS = "https://ossrdbms-aad.database.windows.net/.default"

var defaultOpts = policy.TokenRequestOptions{Scopes: []string{ossRDBMS}}

type postgresStore struct {
	pool        *pgxpool.Pool
	accessToken azcore.AccessToken
	mutex       sync.RWMutex
}

func newPostgresStore(ctx context.Context, connString string) (*postgresStore, error) {
	var store postgresStore
	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, err
	}
	config.BeforeAcquire = store.beforeAcquire
	config.BeforeConnect = store.beforeConnect

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, err
	}

	if err := pool.Ping(ctx); err != nil {
		return nil, err
	}

	store.pool = pool
	return &store, nil
}

func (p *postgresStore) getAndCheckToken() (string, bool) {
	p.mutex.RLock()
	defer p.mutex.RUnlock()
	return p.accessToken.Token, p.accessToken.ExpiresOn.After(time.Now().UTC())
}

func (p *postgresStore) acquireToken(ctx context.Context) (string, error) {
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return "", err
	}
	p.mutex.Lock()
	defer p.mutex.Unlock()
	at, err := cred.GetToken(ctx, defaultOpts)
	if err != nil {
		return "", err
	}
	p.accessToken = at
	return at.Token, nil
}

func (p *postgresStore) beforeAcquire(ctx context.Context, conn *pgx.Conn) bool {
	slog.Debug("BeforeAcquire: Checking access token")
	token, ok := p.getAndCheckToken()
	if token == "" {
		slog.Debug("BeforeAcquire: No access token set")
		return true
	}
	slog.Debug(fmt.Sprintf("BeforeAcquire: Access token still valid: %v", ok))
	return ok
}

func (p *postgresStore) beforeConnect(ctx context.Context, config *pgx.ConnConfig) error {
	if config.Password != "" {
		slog.Debug("BeforeConnect: Password is set")
		return nil
	}
	slog.Debug("BeforeConnect: No password set, checking access token")
	token, ok := p.getAndCheckToken()
	if !ok {
		slog.Debug("BeforeConnect: Acquiring access token")
		var err error
		if token, err = p.acquireToken(ctx); err != nil {
			return err
		}
	}
	config.Password = token
	slog.Info(fmt.Sprintf("Acquired new access token: %s...", config.Password[:10]))
	return nil
}

func (p *postgresStore) list(ctx context.Context, offset int, limit int) ([]todo, error) {
	rows, err := p.pool.Query(
		ctx,
		`SELECT id, description, details, done FROM todo ORDER BY description OFFSET $1 LIMIT $2`,
		int64(offset),
		int64(limit))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return pgx.CollectRows(rows, pgx.RowToStructByPos[todo])
}

func (p *postgresStore) find(ctx context.Context, id int) (todo, error) {
	rows, err := p.pool.Query(
		ctx,
		`SELECT id, description, details, done FROM todo WHERE id = $1`,
		int64(id))
	if err != nil {
		return todo{}, err
	}
	defer rows.Close()
	item, err := pgx.CollectOneRow(rows, pgx.RowToStructByPos[todo])
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return todo{}, err
		}
		// Replace original error with our own sentinel error
		return todo{}, errEmptyResultSet
	}
	return item, nil
}

func (p *postgresStore) create(ctx context.Context, item todo) (todo, error) {
	var id int64
	// We're using QueryRow() instead of Exec() since this allows us to capture the value of the RETURNING clause
	row := p.pool.QueryRow(
		ctx,
		`INSERT INTO todo (id, description, details, done) VALUES (DEFAULT, $1, $2, $3) RETURNING id`,
		item.Description, item.Details, item.Done)
	err := row.Scan(&id)
	if err != nil {
		return item, err
	}
	item.Id = id
	return item, nil
}

func (p *postgresStore) update(ctx context.Context, item todo) (todo, error) {
	tag, err := p.pool.Exec(
		ctx,
		`UPDATE todo SET description = $1, details = $2, done =$3 where id =$4`,
		item.Description,
		item.Details,
		item.Done,
		item.Id)
	if err != nil {
		return item, err
	}
	if tag.RowsAffected() == 0 {
		return item, errEmptyResultSet
	}
	return item, nil
}

func (p *postgresStore) delete(ctx context.Context, id int) error {
	tag, err := p.pool.Exec(
		ctx,
		`DELETE FROM todo where id = $1`,
		id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errEmptyResultSet
	}
	return nil
}

func (p *postgresStore) ping(ctx context.Context) error {
	return p.pool.Ping(ctx)
}

func (p *postgresStore) close(ctx context.Context) {
	p.pool.Close()
}
