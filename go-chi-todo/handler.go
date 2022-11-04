package main

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
)

func newGetHandler(ts *todoStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Println("GET called")
		idParam := chi.URLParam(r, "id")
		if idParam == "" {
			log.Println("missing id")
			http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
			return
		}
		id, err := strconv.Atoi(idParam)
		if err != nil {
			log.Printf("invalid id: %q", idParam)
			http.NotFound(w, r)
			return
		}
		item, err := ts.get(r.Context(), id)
		if err != nil {
			// Quick and dirty, update later!
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		b, err := json.Marshal(item)
		if err != nil {
			// Quick and dirty, update later!
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(b)
	}
}
