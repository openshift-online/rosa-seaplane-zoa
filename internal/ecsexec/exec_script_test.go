package ecsexec

import "testing"

func TestParseExecScriptExitCode_WhenMarkerPresentItShouldReturnLastCode(t *testing.T) {
	out := "banner noise\n" + ExecScriptExitMarker + "0\nmore\n" + ExecScriptExitMarker + "42\n"
	code, err := parseExecScriptExitCode(out)
	if err != nil {
		t.Fatalf("parseExecScriptExitCode: %v", err)
	}
	if code != 42 {
		t.Fatalf("got exit code %d want 42", code)
	}
}

func TestParseExecScriptExitCode_WhenMarkerMissingItShouldError(t *testing.T) {
	_, err := parseExecScriptExitCode("no marker here")
	if err == nil {
		t.Fatal("expected error when marker missing")
	}
}

func TestParseExecScriptExitCode_WhenMOTDPrecedesMarkerItShouldReturnLastCode(t *testing.T) {
	out := "Hello, operator\n==> ZOA Boundary session\n" + ExecScriptExitMarker + "0\n"
	code, err := parseExecScriptExitCode(out)
	if err != nil {
		t.Fatalf("parseExecScriptExitCode: %v", err)
	}
	if code != 0 {
		t.Fatalf("got exit code %d want 0", code)
	}
}
