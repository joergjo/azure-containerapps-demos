package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"log/slog"

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/log"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/postgres"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/router"
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

func run(listenAddr string, connString string, debug bool) {
	slog.SetDefault(slog.New(log.NewStructured(os.Stderr, debug)))

	if connString == "" {
		slog.Info("no connection string specified, using pqlib style PG* environment variables instead")
	}

	if listenAddr == "" {
		listenAddr = ":8080"
	}

	store, err := postgres.NewStore(context.Background(), connString)
	if err != nil {
		slog.Error("initializing data store", log.ErrorKey, err)
		os.Exit(1)
	}

	r := router.NewMux(store)
	s := http.Server{
		Addr:              listenAddr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      5 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	done := make(chan struct{})
	go shutdown(context.Background(), &s, done)

	slog.Info(fmt.Sprintf("starting server, listening on %s", listenAddr))
	err = s.ListenAndServe()
	slog.Info("waiting for shutdown to complete")
	<-done
	slog.Error("server has shut down", log.ErrorKey, err)
	slog.Info("disconnecting from database")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	store.Close(ctx)
	slog.Info("shutdown complete")
}

func shutdown(ctx context.Context, s *http.Server, done chan struct{}) {
	sigch := make(chan os.Signal, 1)
	signal.Notify(sigch, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigch
	slog.Warn(fmt.Sprintf("received signal %v", sig))

	childCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if err := s.Shutdown(childCtx); err != nil {
		slog.Error("shutting down", log.ErrorKey, err)
	}
	close(done)
}
