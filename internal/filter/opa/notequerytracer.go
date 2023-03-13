package opa

import "github.com/open-policy-agent/opa/topdown"

// Wrapper around topdown.BufferTracer that filters out all event types other than Note/Fail type.
type noteQueryTracer struct {
	bt *topdown.BufferTracer
}

func newNoteQueryTracer() *noteQueryTracer {
	return &noteQueryTracer{
		bt: topdown.NewBufferTracer(),
	}
}

// Enabled always returns true if the BufferTracer is instantiated.
func (b *noteQueryTracer) Enabled() bool {
	return b.bt.Enabled()
}

// TraceEvent adds the event to the buffer.
func (b *noteQueryTracer) TraceEvent(evt topdown.Event) {
	if evt.Op == topdown.NoteOp || evt.Op == topdown.FailOp {
		b.bt.TraceEvent(evt)
	}
}

// Config returns the Tracers standard configuration
func (b *noteQueryTracer) Config() topdown.TraceConfig {
	return b.bt.Config()
}
