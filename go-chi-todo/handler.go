package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

func newGetManyHandler(ts *todoStore) http.HandlerFunc {
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
			log.Printf("Error reading from store: %v", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		respond(w, items, nil)
	}
}

func newGetHandler(ts *todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, err := strconv.Atoi(p)
		if err != nil {
			log.Printf("No valid id in request: %v", err)
			http.NotFound(w, r)
		}
		item, err := ts.findOne(r.Context(), id)
		if err != nil {
			if !errors.Is(err, pgx.ErrNoRows) {
				log.Printf("Error reading from store: %v", err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			log.Printf("Item with id %d not found", id)
			http.NotFound(w, r)
			return
		}
		respond(w, item, nil)
	}
}

func newPostHandler(ts *todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("Error reading request body: %v", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		var item todo
		err = json.Unmarshal(body, &item)
		if err != nil {
			log.Printf("Error unmarshalling todo item: %v", err)
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		item, err = ts.create(r.Context(), item)
		if err != nil {
			log.Printf("Error adding todo item to store: %v", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		loc := fmt.Sprintf("%s/%d", r.URL.String(), item.Id)
		h := map[string]string{"Location": loc}
		respond(w, item, h)
	}
}

func newPutHandler(ts *todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, err := strconv.Atoi(p)
		if err != nil {
			log.Printf("No valid id in request: %v", err)
			http.NotFound(w, r)
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("Error reading request body: %v", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		var item todo
		err = json.Unmarshal(body, &item)
		if err != nil {
			log.Printf("Error unmarshalling todo item: %v", err)
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		item.Id = int64(id)
		item, err = ts.update(r.Context(), item)
		if err != nil {
			if !errors.Is(err, errNoRows) {
				log.Printf("Error adding todo item to store: %v", err)
				http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				return
			}
			http.NotFound(w, r)
			return
		}
		respond(w, item, nil)
	}
}

func newDeleteHandler(ts *todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p := chi.URLParam(r, "id")
		id, err := strconv.Atoi(p)
		if err != nil {
			log.Printf("No valid id in request: %v", err)
			http.NotFound(w, r)
		}
		ok, err := ts.delete(r.Context(), id)
		if err != nil {
			log.Printf("Error deleting from store: %v", err)
			http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
			return
		}
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

func respond(w http.ResponseWriter, v any, headers map[string]string) {
	b, err := json.Marshal(v)
	if err != nil {
		log.Printf("Error marshalling object: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	for key, val := range headers {
		w.Header().Set(key, val)
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(b)
}
