package main

import (
	"math/rand"
	"os"
	"time"

	log "github.com/sirupsen/logrus"
)

var worldTranslations = []string{
	"world", "Welt", "世界", "werden",
	"monde", "világ", "mondo", "세계",
	"свет", "świat", "mundo", "Мир",
	"света", "värld", "dünya", "umhlaba",
}

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
	l.Out = os.Stdout
	l.SetFormatter(&log.JSONFormatter{})

	rand.Seed(time.Now().Unix())
	host, err := os.Hostname()
	if err != nil {
		l.Warn("Cannot obtain host name")
	} else {
		l.AddHook(&hostNameFieldHook{hostname: host})
	}
	return l
}

func main() {
	l := newLogger()
	i := rand.Intn(len(worldTranslations))
	l.Printf("Hello %s!", worldTranslations[i])
	// Block longer than our end-start interval
	time.Sleep(time.Duration(60 * time.Minute))
}
