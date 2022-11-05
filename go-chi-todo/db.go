package main

import (
	"context"
	"errors"
	"log"
	"sync"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore/policy"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const ossRDBMS = "https://ossrdbms-aad.database.windows.net"

var defaultOpts = policy.TokenRequestOptions{Scopes: []string{ossRDBMS}}

var errNoRows = errors.New("update affected no rows")

type todo struct {
	Id          int64  `json:"id"`
	Description string `json:"description"`
	Details     string `json:"details"`
	Done        bool   `json:"done"`
}

type todoStore struct {
	pool        *pgxpool.Pool
	accessToken azcore.AccessToken
	mutex       sync.RWMutex
}

func newTodoStore(ctx context.Context, connString string) (*todoStore, error) {
	store := todoStore{}

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
	store.pool = pool

	if err := pool.Ping(ctx); err != nil {
		return nil, err
	}
	return &store, nil
}

func (t *todoStore) getToken() string {
	t.mutex.RLock()
	defer t.mutex.RUnlock()
	return t.accessToken.Token
}

func (t *todoStore) acquireToken(ctx context.Context) error {
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Printf("Error acquiring identity: %v", err)
		return err
	}
	t.mutex.Lock()
	defer t.mutex.Unlock()
	at, err := cred.GetToken(ctx, defaultOpts)
	if err != nil {
		log.Printf("Error acquiring token: %v", err)
		return err
	}
	t.accessToken = at
	return nil
}

func (t *todoStore) tokenValid() bool {
	t.mutex.RLock()
	defer t.mutex.RUnlock()
	return t.accessToken.ExpiresOn.After(time.Now().UTC())
}

func (t *todoStore) beforeAcquire(ctx context.Context, conn *pgx.Conn) bool {
	log.Println("BeforeAcquire: Checking access token")
	token := t.getToken()
	if token == "" {
		log.Println("BeforeAcquire: No access token set")
		return true
	}
	isValid := t.tokenValid()
	log.Printf("BeforeAcquire: Access token still valid: %v", isValid)
	return isValid
}

func (t *todoStore) beforeConnect(ctx context.Context, config *pgx.ConnConfig) error {
	if config.Password != "" {
		log.Println("BeforeConnect: Password is set")
		return nil
	}
	log.Println("BeforeConnect: No password set, checking access token...")
	if !t.tokenValid() {
		log.Println("BeforeConnect: Acquiring access token...")
		if err := t.acquireToken(ctx); err != nil {
			return err
		}
	}
	config.Password = t.getToken()
	log.Printf("Acquired new access token: %s...", config.Password[:10])
	return nil
}

func (t *todoStore) list(ctx context.Context, offset int, limit int) ([]todo, error) {
	rows, err := t.pool.Query(
		ctx,
		`SELECT id, description, details, done FROM todo OFFSET $1 LIMIT $2`,
		int64(offset),
		int64(limit))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return pgx.CollectRows(rows, pgx.RowToStructByPos[todo])
}

func (t *todoStore) findOne(ctx context.Context, id int) (todo, error) {
	rows, err := t.pool.Query(
		ctx,
		`SELECT id, description, details, done FROM todo WHERE id = $1`,
		int64(id))
	if err != nil {
		return todo{}, err
	}
	defer rows.Close()
	return pgx.CollectOneRow(rows, pgx.RowToStructByPos[todo])
}

func (t *todoStore) create(ctx context.Context, item todo) (todo, error) {
	var id int64
	// We're using QueryRow() instead of Exec() since this allows us to capture the value of the RETURNING clause
	row := t.pool.QueryRow(
		ctx,
		`INSERT INTO todo (id, description, details, done) VALUES (nextval('hibernate_sequence'), $1, $2, $3) RETURNING id`,
		item.Description, item.Details, item.Done)
	err := row.Scan(&id)
	if err != nil {
		return item, err
	}
	item.Id = id
	return item, nil
}

func (t *todoStore) update(ctx context.Context, item todo) (todo, error) {
	tag, err := t.pool.Exec(
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
		return item, errNoRows
	}
	return item, nil
}

func (t *todoStore) delete(ctx context.Context, id int) (bool, error) {
	tag, err := t.pool.Exec(
		ctx,
		`DELETE FROM todo where id = $1`,
		id)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

func (t *todoStore) close(ctx context.Context) {
	t.pool.Close()
}
