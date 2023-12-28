package main

import (
	"flag"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"time"

	log "github.com/sirupsen/logrus"
)

var worldTranslations = []string{
	"world", "Welt", "世界", "werden",
	"monde", "világ", "mondo", "세계",
	"свет", "świat", "mundo", "Мир",
	"света", "värld", "dünya", "umhlaba",
}

const (
	enableAboutEnvVar = "HELLOWORLD_ENABLE_ABOUT"
)

type hostNameFieldHook struct {
	hostname string
}

func (h *hostNameFieldHook) Levels() []log.Level {
	return log.AllLevels
}

func (h *hostNameFieldHook) Fire(e *log.Entry) error {
	e.Data["hostname"] = h.hostname
	return nil
}

func newLogger() log.FieldLogger {
	l := log.New()
	l.Out = os.Stderr
	l.SetFormatter(&log.JSONFormatter{})

	host, err := os.Hostname()
	if err != nil {
		l.Warn("Cannot obtain host name")
	} else {
		l.AddHook(&hostNameFieldHook{hostname: host})
	}
	return l
}

func main() {
	port := flag.Int("port", 8000, "HTTP listen port")
	flag.Parse()

	l := newLogger()
	enableAbout := false
	if env, ok := os.LookupEnv(enableAboutEnvVar); ok {
		var err error
		if enableAbout, err = strconv.ParseBool(env); err != nil {
			l.Warnf("%s set to non-boolean value %q, ignoring", enableAboutEnvVar, env)
		}
	}

	mux := &http.ServeMux{}
	mux.HandleFunc("/hello", hello(l))
	mux.HandleFunc("/about", about(l, enableAbout))
	mux.HandleFunc("/", probe(l, "OK"))

	addr := fmt.Sprintf(":%d", *port)
	s := http.Server{
		Addr:         addr,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 90 * time.Second,
		IdleTimeout:  120 * time.Second,
		Handler:      mux,
	}

	l.Printf("Listening on %s", addr)

	if err := s.ListenAndServe(); err != http.ErrServerClosed {
		l.Fatalln(err)
	}
}

func hello(l log.FieldLogger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		i := rand.Intn(len(worldTranslations))
		msg := fmt.Sprintf("Hello %s!", worldTranslations[i])
		l.Printf("Sending %q", msg)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, msg)
	}
}

func about(l log.FieldLogger, enabled bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if enabled {
			msg := fmt.Sprintf("Built with %s", runtime.Version())
			l.Printf("Sending %q", msg)
			w.Header().Set("Content-Type", "text/plain")
			fmt.Fprint(w, msg)
		} else {
			l.Warn("About handler is disabled")
			http.Error(w, "This handler is not implemented. Please update to a newer version if available.", http.StatusNotImplemented)
		}
	}
}

func probe(l log.FieldLogger, msg string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l.Printf("Sending %q", msg)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, msg)
	}
}
