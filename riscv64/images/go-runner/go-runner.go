/*
Copyright 2020 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// go-runner is a simple wrapper around process execution intended for use
// in distroless container images. It provides optional log file redirection
// and signal forwarding.
package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
)

var (
	logFilePath    = flag.String("log-file", "", "If non-empty, write to this log file")
	alsoToStdout   = flag.Bool("also-stdout", false, "When writing to a log file, also write to stdout")
	redirectStderr = flag.Bool("redirect-stderr", true, "Redirect stderr to the log file or stdout")
)

func main() {
	flag.Parse()

	args := flag.Args()
	if len(args) == 0 {
		log.Fatal("No command supplied")
	}

	var logWriter io.Writer = os.Stdout

	if *logFilePath != "" {
		logFile, err := os.OpenFile(*logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			log.Fatalf("Failed to open log file %q: %v", *logFilePath, err)
		}
		defer logFile.Close()

		if *alsoToStdout {
			logWriter = io.MultiWriter(logFile, os.Stdout)
		} else {
			logWriter = logFile
		}
	}

	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = logWriter
	if *redirectStderr {
		cmd.Stderr = logWriter
	} else {
		cmd.Stderr = os.Stderr
	}
	cmd.Stdin = os.Stdin

	// Forward signals to the child process
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)

	if err := cmd.Start(); err != nil {
		log.Fatalf("Error starting command: %v", err)
	}

	go func() {
		for sig := range sigCh {
			cmd.Process.Signal(sig)
		}
	}()

	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
