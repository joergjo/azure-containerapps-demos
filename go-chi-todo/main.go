package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func shutdown(ctx context.Context, s *http.Server, done chan struct{}) {
	sigch := make(chan os.Signal, 1)
	signal.Notify(sigch, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigch
	log.Printf("Got signal: %v. Server shutting down.", sig)

	childCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if err := s.Shutdown(childCtx); err != nil {
		log.Printf("Error during shutdown: %v", err)
	}
	done <- struct{}{}
}

func main() {
	connString := os.Getenv("TODO_CONN_STRING")
	if connString == "" {
		log.Println("No connection string specified, using pqlib style PG* environment variables instead")
	}
	listenAddr := os.Getenv("TODO_LISTEN_ADDR")
	if listenAddr == "" {
		listenAddr = ":8080"
	}

	store, err := newTodoStore(context.Background(), connString)
	if err != nil {
		log.Fatal(err)
	}
	defer store.close(context.Background())

	r := chi.NewRouter()
	r.Use(middleware.StripSlashes)
	r.Get("/todo", newGetManyHandler(store))
	r.Post("/todo", newPostHandler(store))
	r.Get("/todo/{id}", newGetHandler(store))
	r.Put("/todo/{id}", newPutHandler(store))
	r.Delete("/todo/{id}", newDeleteHandler(store))

	s := http.Server{
		Addr:              listenAddr,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      5 * time.Second,
	}

	done := make(chan struct{})
	go shutdown(context.Background(), &s, done)

	log.Printf("Starting server, listening on %s", listenAddr)
	err = s.ListenAndServe()
	log.Println("Waiting for shutdown to complete...")
	<-done
	log.Fatal(err)
}
