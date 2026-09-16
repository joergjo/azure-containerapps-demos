package router

import (
	"encoding/json/v2"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/joergjo/azure-containerapps-demos/go-chi-todo/internal/log"
)

func bind(r *http.Request, v any) error {
	err := json.UnmarshalRead(r.Body, v, json.RejectUnknownMembers(true))
	if err != nil {
		slog.Error("decoding response", log.ErrorKey, err)
		return err
	}
	return nil
}

func respond(w http.ResponseWriter, data any, status int, headers ...header) {
	for _, h := range headers {
		w.Header().Add(h.name, h.val)
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	err := json.MarshalWrite(w, data)
	if err != nil {
		slog.Error("encoding response", log.ErrorKey, err, slog.String("type", fmt.Sprintf("%T", data)))
	}
}
