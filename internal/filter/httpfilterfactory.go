package filter

type HttpFilterFactory interface {
	// Invoked to create a new instance of a filter for every new proxy stream request.
	CreateFilter() HttpFilter
}
