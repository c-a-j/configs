package main

import "testing"

func Test...(t *testing.T) {

    t.Run("...", func(t *testing.T) {
        got := ...()
        want := 
        assert...(t, got, want)
    })
}

func assert...(t testing.TB, got, want bool) {
    t.Helper()
    if got != want {
        t.Errorf("got %d want %d", got, want)
    }
}

