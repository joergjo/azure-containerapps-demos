package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"log/slog"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type header struct {
	name string
	val  string
}

func newRouter(ts todoStore) *chi.Mux {
	r := chi.NewRouter()
	r.Use(
		middleware.StripSlashes,
		middleware.GetHead,
		middleware.Heartbeat("/healthz"),
		middleware.AllowContentType("application/json"))
	r.Get("/ready", readyHandler(ts))
	r.Get("/todo", getManyHandler(ts))
	r.Post("/todo", postHandler(ts))
	r.Get("/todo/{id:[0-9]+}", getHandler(ts))
	r.Put("/todo/{id:[0-9]+}", putHandler(ts))
	r.Delete("/todo/{id:[0-9]+}", deleteHandler(ts))
	return r
}

func getManyHandler(ts todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Query().Get("offset")
		offset, err := strconv.Atoi(p)
		if err != nil {
			offset = 0
		}
		p = r.URL.Query().Get("limit")
		limit, err := strconv.Atoi(p)
		if err != nil {
			limit = 50
		}
		items, err := ts.list(r.Context(), offset, limit)
		if err != nil {
			slog.Error("Error reading from store", ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		respond(w, items)
	}
}

func getHandler(ts todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, _ := strconv.Atoi(p)
		item, err := ts.find(r.Context(), id)
		if err != nil {
			if !errors.Is(err, errEmptyResultSet) {
				slog.Error("Error reading from store", ErrorKey, err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			slog.Info(fmt.Sprintf("Item with id %d not found", id))
			http.NotFound(w, r)
			return
		}
		respond(w, item)
	}
}

func postHandler(ts todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var item todo
		if err := bind(r, &item); err != nil {
			slog.Error("Error binding request body", ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return

		}
		item, err := ts.create(r.Context(), item)
		if err != nil {
			slog.Error("Error creating new todo item to store", ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		loc := fmt.Sprintf("%s/%d", r.URL.String(), item.Id)
		respond(w, item, header{name: "Location", val: loc})
	}
}

func putHandler(ts todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var item todo
		if err := bind(r, &item); err != nil {
			slog.Error("Error binding request body", ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return

		}
		p := chi.URLParam(r, "id")
		id, _ := strconv.Atoi(p)
		item.Id = int64(id)
		item, err := ts.update(r.Context(), item)
		if err != nil {
			if !errors.Is(err, errEmptyResultSet) {
				slog.Error("Error updating todo item in store", ErrorKey, err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			slog.Info(fmt.Sprintf("Item with id %d not found", id))
			http.NotFound(w, r)
			return
		}
		respond(w, item)
	}
}

func deleteHandler(ts todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, _ := strconv.Atoi(p)
		err := ts.delete(r.Context(), id)
		if err != nil {
			if !errors.Is(err, errEmptyResultSet) {
				slog.Error("Error deleting from store", ErrorKey, err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			slog.Info(fmt.Sprintf("Item with id %d not found", id))
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func readyHandler(ts todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := ts.ping(r.Context()); err != nil {
			slog.Error("Error checking readiness", ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
	}
}

func bind(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

func respond(w http.ResponseWriter, v any, headers ...header) {
	b, err := json.Marshal(v)
	if err != nil {
		slog.Error("Error encoding object", ErrorKey, err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	for _, h := range headers {
		w.Header().Add(h.name, h.val)
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(b)
}
