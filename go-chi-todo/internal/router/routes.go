package router

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"log/slog"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/log"
	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/model"
)

type header struct {
	name string
	val  string
}

func NewMux(ts model.TodoStore) *chi.Mux {
	r := chi.NewRouter()
	r.Use(
		middleware.StripSlashes,
		middleware.GetHead,
		middleware.Heartbeat("/healthz/live"),
		middleware.AllowContentType("application/json"))
	r.Get("/healthz/ready", readyHandler(ts))
	r.Get("/todo", getManyHandler(ts))
	r.Post("/todo", postHandler(ts))
	r.Get("/todo/{id:[0-9]+}", getHandler(ts))
	r.Put("/todo/{id:[0-9]+}", putHandler(ts))
	r.Delete("/todo/{id:[0-9]+}", deleteHandler(ts))
	return r
}

func getManyHandler(ts model.TodoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Query().Get("offset")
		offset, err := strconv.Atoi(p)
		if err != nil {
			offset = 0
		}
		p = r.URL.Query().Get("limit")
		limit, err := strconv.Atoi(p)
		if err != nil || limit < 1 {
			limit = 50
		}
		items, err := ts.List(r.Context(), offset, limit)
		if err != nil {
			slog.Error("reading from store", log.ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		respond(w, items, http.StatusOK)
	}
}

func getHandler(ts model.TodoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, _ := strconv.Atoi(p)
		item, err := ts.Find(r.Context(), id)
		if err != nil {
			if !errors.Is(err, model.ErrEmptyResultSet) {
				slog.Error("reading from store", log.ErrorKey, err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			slog.Info(fmt.Sprintf("item with id %d not found", id))
			http.NotFound(w, r)
			return
		}
		respond(w, item, http.StatusOK)
	}
}

func postHandler(ts model.TodoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Content-Type") != "application/json" {
			slog.Error("invalid content type", log.ErrorKey, "expected application/json")
			http.Error(w, http.StatusText(http.StatusUnsupportedMediaType), http.StatusUnsupportedMediaType)
			return
		}
		defer r.Body.Close()
		var item model.Todo
		if err := bind(r, &item); err != nil {
			slog.Error("binding request body", log.ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return

		}
		item, err := ts.Create(r.Context(), item)
		if err != nil {
			slog.Error("creating new todo item to store", log.ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		loc := fmt.Sprintf("%s/%d", r.URL.String(), item.Id)
		respond(w, item, http.StatusCreated, header{name: "Location", val: loc})
	}
}

func putHandler(ts model.TodoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Content-Type") != "application/json" {
			slog.Error("invalid content type", log.ErrorKey, "expected application/json")
			http.Error(w, http.StatusText(http.StatusUnsupportedMediaType), http.StatusUnsupportedMediaType)
			return
		}
		defer r.Body.Close()
		var item model.Todo
		if err := bind(r, &item); err != nil {
			slog.Error("binding request body", log.ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return

		}
		p := chi.URLParam(r, "id")
		id, _ := strconv.Atoi(p)
		item.Id = int64(id)
		item, err := ts.Update(r.Context(), item)
		if err != nil {
			if !errors.Is(err, model.ErrEmptyResultSet) {
				slog.Error("updating todo item in store", log.ErrorKey, err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			slog.Info(fmt.Sprintf("item with id %d not found", id))
			http.NotFound(w, r)
			return
		}
		respond(w, item, http.StatusOK)
	}
}

func deleteHandler(ts model.TodoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, _ := strconv.Atoi(p)
		err := ts.Delete(r.Context(), id)
		if err != nil {
			if !errors.Is(err, model.ErrEmptyResultSet) {
				slog.Error("deleting from store", log.ErrorKey, err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			slog.Info(fmt.Sprintf("item with id %d not found", id))
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func readyHandler(ts model.TodoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := ts.Ping(r.Context()); err != nil {
			slog.Error("checking readiness", log.ErrorKey, err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
	}
}
