package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"log/slog"
)

func main() {
	debug := false
	debugEnv := strings.ToLower(os.Getenv("TODO_DEBUG"))
	if debugEnv == "yes" || debugEnv == "true" || debugEnv == "on" || debugEnv == "1" {
		debug = true
	}

	connString := os.Getenv("TODO_CONN_STRING")
	listenAddr := os.Getenv("TODO_LISTEN_ADDR")

	run(listenAddr, connString, debug)
}

func newLogger(w io.Writer, debug bool) *slog.JSONHandler {
	opts := slog.HandlerOptions{
		ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
			if a.Key == slog.TimeKey {
				return slog.Time(a.Key, a.Value.Time().UTC())
			}
			return a
		},
	}
	if debug {
		opts.Level = slog.LevelDebug
	}
	return slog.NewJSONHandler(w, &opts)
}

func run(listenAddr string, connString string, debug bool) {
	slog.SetDefault(slog.New(newLogger(os.Stderr, debug)))

	if connString == "" {
		slog.Info("No connection string specified, using pqlib style PG* environment variables instead")
	}

	if listenAddr == "" {
		listenAddr = ":8080"
	}

	store, err := newPostgresStore(context.Background(), connString)
	if err != nil {
		slog.Error("Failed to initialize data store", ErrorKey, err)
		os.Exit(1)
	}

	r := newRouter(store)
	s := http.Server{
		Addr:              listenAddr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      5 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	done := make(chan struct{})
	go shutdown(context.Background(), &s, done)

	slog.Info(fmt.Sprintf("Starting server, listening on %s", listenAddr))
	err = s.ListenAndServe()
	slog.Info("Waiting for shutdown to complete")
	<-done
	slog.Error("Server has shut down", ErrorKey, err)
	slog.Info("Disconnecting from database")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	store.close(ctx)
	slog.Info("Shutdown complete")
}

func shutdown(ctx context.Context, s *http.Server, done chan struct{}) {
	sigch := make(chan os.Signal, 1)
	signal.Notify(sigch, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigch
	slog.Warn(fmt.Sprintf("Got signal %v", sig))

	childCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if err := s.Shutdown(childCtx); err != nil {
		slog.Error("Error during shutdown", ErrorKey, err)
	}
	done <- struct{}{}
}
