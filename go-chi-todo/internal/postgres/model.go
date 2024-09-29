package postgres

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

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/model"
)

const ossRDBMS = "https://ossrdbms-aad.database.windows.net/.default"

var defaultOpts = policy.TokenRequestOptions{Scopes: []string{ossRDBMS}}

type TodoStore struct {
	pool        *pgxpool.Pool
	accessToken azcore.AccessToken
	mutex       sync.RWMutex
}

func NewStore(ctx context.Context, connString string) (*TodoStore, error) {
	var store TodoStore
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

func (ts *TodoStore) getAndCheckToken() (string, bool) {
	ts.mutex.RLock()
	defer ts.mutex.RUnlock()
	return ts.accessToken.Token, ts.accessToken.ExpiresOn.After(time.Now().UTC())
}

func (ts *TodoStore) acquireToken(ctx context.Context) (string, error) {
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		return "", err
	}
	ts.mutex.Lock()
	defer ts.mutex.Unlock()
	at, err := cred.GetToken(ctx, defaultOpts)
	if err != nil {
		return "", err
	}
	ts.accessToken = at
	return at.Token, nil
}

func (ts *TodoStore) beforeAcquire(ctx context.Context, conn *pgx.Conn) bool {
	slog.Debug("BeforeAcquire: Checking access token")
	token, ok := ts.getAndCheckToken()
	if token == "" {
		slog.Debug("BeforeAcquire: No access token set")
		return true
	}
	slog.Debug(fmt.Sprintf("BeforeAcquire: Access token still valid: %v", ok))
	return ok
}

func (ts *TodoStore) beforeConnect(ctx context.Context, config *pgx.ConnConfig) error {
	if config.Password != "" {
		slog.Debug("BeforeConnect: Password is set")
		return nil
	}
	slog.Debug("BeforeConnect: No password set, checking access token")
	token, ok := ts.getAndCheckToken()
	if !ok {
		slog.Debug("BeforeConnect: Acquiring access token")
		var err error
		if token, err = ts.acquireToken(ctx); err != nil {
			return err
		}
	}
	config.Password = token
	slog.Info(fmt.Sprintf("Acquired new access token: %s...", config.Password[:10]))
	return nil
}

func (ts *TodoStore) List(ctx context.Context, offset int, limit int) ([]model.Todo, error) {
	rows, err := ts.pool.Query(
		ctx,
		`SELECT id, description, details, done FROM todo ORDER BY description OFFSET $1 LIMIT $2`,
		int64(offset),
		int64(limit))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return pgx.CollectRows(rows, pgx.RowToStructByPos[model.Todo])
}

func (ts *TodoStore) Find(ctx context.Context, id int) (model.Todo, error) {
	rows, err := ts.pool.Query(
		ctx,
		`SELECT id, description, details, done FROM todo WHERE id = $1`,
		int64(id))
	if err != nil {
		return model.Todo{}, err
	}
	defer rows.Close()
	item, err := pgx.CollectOneRow(rows, pgx.RowToStructByPos[model.Todo])
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return model.Todo{}, err
		}
		// Replace original error with our own sentinel error
		return model.Todo{}, model.ErrEmptyResultSet
	}
	return item, nil
}

func (ts *TodoStore) Create(ctx context.Context, item model.Todo) (model.Todo, error) {
	var id int64
	// We're using QueryRow() instead of Exec() since this allows us to capture the value of the RETURNING clause
	row := ts.pool.QueryRow(
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

func (ts *TodoStore) Update(ctx context.Context, item model.Todo) (model.Todo, error) {
	tag, err := ts.pool.Exec(
		ctx,
		`UPDATE todo SET description = $1, details = $2, done = $3 where id = $4`,
		item.Description,
		item.Details,
		item.Done,
		item.Id)
	if err != nil {
		return item, err
	}
	if tag.RowsAffected() == 0 {
		return item, model.ErrEmptyResultSet
	}
	return item, nil
}

func (ts *TodoStore) Delete(ctx context.Context, id int) error {
	tag, err := ts.pool.Exec(
		ctx,
		`DELETE FROM todo where id = $1`,
		id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return model.ErrEmptyResultSet
	}
	return nil
}

func (ts *TodoStore) Ping(ctx context.Context) error {
	return ts.pool.Ping(ctx)
}

func (ts *TodoStore) Close(ctx context.Context) {
	ts.pool.Close()
}
