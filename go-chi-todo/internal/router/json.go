package router

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/log"
)

func bind(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return err
	}
	// Ensure the body contains only a single JSON value.
	if err := dec.Decode(&struct{}{}); err != io.EOF {
		if err == nil {
			return fmt.Errorf("request body must contain only a single JSON value")
		}
		return err
	}
	return nil
}

func respond(w http.ResponseWriter, data any, status int, headers ...header) {
	b, err := json.Marshal(data)
	if err != nil {
		slog.Error("encoding response", log.ErrorKey, err, slog.String("type", fmt.Sprintf("%T", data)))
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	for _, h := range headers {
		w.Header().Add(h.name, h.val)
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	w.Write(b)
}
