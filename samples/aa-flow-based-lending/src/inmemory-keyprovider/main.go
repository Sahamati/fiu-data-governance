package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

var store InMemoryKeyProvider

func init() {
	store = *NewInMemoryKeyProvider()
}

type getResponse struct {
	Value string `json:"value"`
}

type setRequest struct {
	Id    string `json:"id"`
	Value string `json:"value"`
}

type setResponse struct {
	Id string `json:"id"`
}

func getValue(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]
	value := store.GetValue(id)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(&getResponse{
		Value: value,
	})
}

func getAllValues(w http.ResponseWriter, r *http.Request) {
	fmt.Println("Endpoint hit: getAllValues")
	values := make(map[string]string)
	for k, v := range store.store {
		values[k] = v
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(&values)
}

func setValue(w http.ResponseWriter, r *http.Request) {
	reqBody, _ := io.ReadAll(r.Body)
	var input setRequest
	_ = json.Unmarshal(reqBody, &input)
	id := store.SetValue(input.Id, input.Value)
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(&setResponse{
		Id: id,
	})
}

func handleRequests() {
	fmt.Println("Starting inmemory-keyprovider server")
	myRouter := mux.NewRouter().StrictSlash(true)
	myRouter.HandleFunc("/items/{id}", getValue).Methods("GET")
	myRouter.HandleFunc("/item", setValue).Methods("POST")
	myRouter.HandleFunc("/items", getAllValues).Methods("GET")
	log.Fatal(http.ListenAndServe(":8285", myRouter))
}

func main() {
	handleRequests()
}

type InMemoryKeyProvider struct {
	store map[string]string
}

func NewInMemoryKeyProvider() *InMemoryKeyProvider {
	return &InMemoryKeyProvider{
		store: make(map[string]string),
	}
}

func (m *InMemoryKeyProvider) SetValue(id, value string) string {
	m.store[id] = value
	return id
}

func (m *InMemoryKeyProvider) GetValue(id string) string {
	v, found := m.store[id]
	if !found {
		return ""
	}

	return v
}
