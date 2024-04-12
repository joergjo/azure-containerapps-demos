package main

import (
	"context"
	"flag"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"time"

	log "github.com/sirupsen/logrus"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/trace"
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
	f := log.JSONFormatter{
		FieldMap: log.FieldMap{
			log.FieldKeyTime: "timestamp",
		},
	}
	l.SetFormatter(&f)

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

	ctx := context.Background()

	// Configure a new OTLP exporter using environment variables for sending data to Honeycomb over gRPC
	client := otlptracegrpc.NewClient()
	exp, err := otlptrace.New(ctx, client)
	if err != nil {
		l.Fatalf("failed to initialize exporter: %e", err)
	}

	// Create a new tracer provider with a batch span processor and the otlp exporter
	tp := trace.NewTracerProvider(
		trace.WithBatcher(exp),
	)

	// Handle shutdown to ensure all sub processes are closed correctly and telemetry is exported
	defer func() {
		if err := exp.Shutdown(ctx); err != nil {
			l.Warnf("failed to shutdown exporter: %e", err)
		}
		if err := tp.Shutdown(ctx); err != nil {
			l.Warnf("failed to shutdown tracer provider: %e", err)
		}
	}()

	// Register the global Tracer provider
	otel.SetTracerProvider(tp)

	// Register the W3C trace context and baggage propagators so data is propagated across services/processes
	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)

	mux := http.NewServeMux()
	mux.Handle("GET /hello", hello(l))
	mux.Handle("GET /about", about(l, enableAbout))
	mux.Handle("GET /", probe(l, "OK"))

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

func hello(l log.FieldLogger) http.Handler {
	h := func(w http.ResponseWriter, r *http.Request) {
		i := rand.Intn(len(worldTranslations))
		msg := fmt.Sprintf("Hello %s!", worldTranslations[i])
		l.Printf("Sending %q", msg)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, msg)
	}
	return otelhttp.NewHandler(http.HandlerFunc(h), "hello")
}

func about(l log.FieldLogger, enabled bool) http.Handler {
	h := func(w http.ResponseWriter, r *http.Request) {
		if enabled {
			msg := fmt.Sprintf("Built with %s", runtime.Version())
			l.Printf("Sending %q", msg)
			w.Header().Set("Content-Type", "text/plain")
			fmt.Fprint(w, msg)
		} else {
			l.Warn("About handler is disabled")
			http.Error(w, "This handler is disabled. Please set HELLOWORLD_ENABLE_ABOUT to 'true' to enable.", http.StatusNotImplemented)
		}
	}
	return otelhttp.NewHandler(http.HandlerFunc(h), "about")
}

func probe(l log.FieldLogger, msg string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		l.Printf("Sending %q", msg)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, msg)
	})
}

// func main2() {
// 	ctx := context.Background()

// 	// Configure a new OTLP exporter using environment variables for sending data to Honeycomb over gRPC
// 	client := otlptracegrpc.NewClient()
// 	exp, err := otlptrace.New(ctx, client)
// 	if err != nil {
// 		log.Fatalf("failed to initialize exporter: %e", err)
// 	}

// 	// Create a new tracer provider with a batch span processor and the otlp exporter
// 	tp := trace.NewTracerProvider(
// 		trace.WithBatcher(exp),
// 	)

// 	// Handle shutdown to ensure all sub processes are closed correctly and telemetry is exported
// 	defer func() {
// 		_ = exp.Shutdown(ctx)
// 		_ = tp.Shutdown(ctx)
// 	}()

// 	// Register the global Tracer provider
// 	otel.SetTracerProvider(tp)

// 	// Register the W3C trace context and baggage propagators so data is propagated across services/processes
// 	otel.SetTextMapPropagator(
// 		propagation.NewCompositeTextMapPropagator(
// 			propagation.TraceContext{},
// 			propagation.Baggage{},
// 		),
// 	)

// 	// Implement an HTTP handler func to be instrumented
// 	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
// 		fmt.Fprintf(w, "Hello, World")
// 	})

// 	// Setup handler instrumentation
// 	wrappedHandler := otelhttp.NewHandler(handler, "hello")
// 	http.Handle("/hello", wrappedHandler)

// 	// Start web server
// 	log.Fatal(http.ListenAndServe(":3030", nil))
// }
