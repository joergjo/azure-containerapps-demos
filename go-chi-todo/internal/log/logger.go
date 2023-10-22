package log

import (
	"io"
	"log/slog"
)

func NewStructured(w io.Writer, debug bool) *slog.JSONHandler {
	opts := slog.HandlerOptions{
		ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
			if a.Key == slog.TimeKey {
				return slog.Time(a.Key, a.Value.Time().UTC())
			}
			return a
		},
	}
	if debug {
		opts.Level = slog.LevelDebug
	}
	return slog.NewJSONHandler(w, &opts)
}
