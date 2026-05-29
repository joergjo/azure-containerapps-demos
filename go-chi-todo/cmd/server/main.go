package main

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"runtime/debug"
	"strings"
	"syscall"
	"time"

	"log/slog"

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/log"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/postgres"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/router"
)

var (
	vcsRevision string
	vcsDate     string
)

func main() {
	dbg := false
	dbgEnv := strings.ToLower(os.Getenv("TODO_DEBUG"))
	if dbgEnv == "yes" || dbgEnv == "true" || dbgEnv == "on" || dbgEnv == "1" {
		dbg = true
	}

	connString := os.Getenv("TODO_CONN_STRING")
	listenAddr := os.Getenv("TODO_LISTEN_ADDR")

	os.Exit(run(listenAddr, connString, dbg))
}

func run(listenAddr string, connString string, dbg bool) int {
	slog.SetDefault(slog.New(log.NewStructured(os.Stderr, dbg)))

	info, ok := debug.ReadBuildInfo()
	if ok {
		slog.Info("todo-api", "revision", commitInfo(info, "vcs.revision", vcsRevision), "date", commitInfo(info, "vcs.time", vcsDate), "goVersion", runtime.Version(), "goMaxProcs", runtime.GOMAXPROCS(0))
	}

	if connString == "" {
		slog.Info("no connection string specified, using pqlib style PG* environment variables instead")
	}

	if listenAddr == "" {
		listenAddr = ":8080"
	}

	startupCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	store, err := postgres.NewStore(startupCtx, connString)
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
	slog.Info("starting server", slog.String("addr", listenAddr))
	slog.Info("configured CPU limit", "GOMAXPROCS", runtime.GOMAXPROCS(0))
	go func() {
		defer close(errC)
		if err := s.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errC <- err
		}
	}()

	sigC := make(chan os.Signal, 1)
	signal.Notify(sigC, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err, ok := <-errC:
		if !ok {
			break
		}
		slog.Error("server error", log.ErrorKey, err)
		return 1
	case sig := <-sigC:
		signal.Stop(sigC)
		slog.Warn("received signal", slog.String("signal", sig.String()))
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

func commitInfo(info *debug.BuildInfo, key string, fallback string) string {
	for _, s := range info.Settings {
		if s.Key == key {
			return s.Value
		}
	}
	return fallback
}
