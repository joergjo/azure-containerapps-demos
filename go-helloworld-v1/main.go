package main

import (
	"flag"
	"fmt"
	"math/rand"
	"net/http"
	"os"
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
	addVersionEnvVar = "HELLOWORLD_ADD_VERSION"
	hostField        = "host"
	version          = "v1"
)

func main() {
	log.SetFormatter(&log.JSONFormatter{})
	rand.Seed(time.Now().Unix())
	host, err := os.Hostname()
	if err != nil {
		host = "unknown"
		log.WithField(hostField, host).Warn("Cannot obtain host name")
	}

	port := flag.Int("port", 5000, "HTTP listen port")
	flag.Parse()

	addVer := false
	if env, ok := os.LookupEnv(addVersionEnvVar); ok {
		var err error
		if addVer, err = strconv.ParseBool(env); err != nil {
			log.WithField(hostField, host).Warnf("%s set non-boolean value %q, ignoring...", addVersionEnvVar, env)
		}
	}

	mux := &http.ServeMux{}
	mux.HandleFunc("/sayHelloWorld", sayHelloWorld(host, addVer))
	mux.HandleFunc("/about", about)

	addr := fmt.Sprintf(":%d", *port)
	s := http.Server{
		Addr:         addr,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 90 * time.Second,
		IdleTimeout:  120 * time.Second,
		Handler:      mux,
	}

	log.WithField(hostField, host).Printf("Listening on %s...", addr)

	if err = s.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalln(err)
	}
}

func sayHelloWorld(host string, addVer bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		i := rand.Intn(len(worldTranslations))
		msg := fmt.Sprintf("Hello %s from %s!", worldTranslations[i], host)
		if addVer {
			msg = fmt.Sprintf("[%s] %s", version, msg)
		}
		log.WithField(hostField, host).Printf("Sending %q", msg)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, msg)
	}
}

func about(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "This handler is not implemented. Please update to a newer version if available.", http.StatusNotImplemented)
}
