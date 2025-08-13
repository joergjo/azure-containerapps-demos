package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"runtime"
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

	os.Exit(run(listenAddr, connString, debug))
}

func run(listenAddr string, connString string, debug bool) int {
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
		return 1
	}

	r := router.NewMux(store)
	s := http.Server{
		Addr:              listenAddr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      5 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	errC := make(chan error, 1)
	slog.Info(fmt.Sprintf("starting server, listening on %s", listenAddr))
	slog.Info("configured CPU limit", "GOMAXPROCS", runtime.GOMAXPROCS(0))
	go func() {
		errC <- s.ListenAndServe()
	}()

	sigC := make(chan os.Signal, 1)
	signal.Notify(sigC, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-errC:
		slog.Error("server error", log.ErrorKey, err)
	case sig := <-sigC:
		signal.Stop(sigC)
		slog.Warn(fmt.Sprintf("received signal %v", sig))
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		slog.Info("waiting for shutdown to complete")
		if err := s.Shutdown(ctx); err != nil {
			slog.Error("shutting down", log.ErrorKey, err)
		}
		slog.Info("shutdown complete")
	}

	slog.Info("disconnecting from database")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := store.Close(ctx); err != nil {
		slog.Warn("closing data store", log.ErrorKey, err)
	}

	slog.Info("exiting")
	return 0
}
