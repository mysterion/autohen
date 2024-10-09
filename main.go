package main

import (
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"strings"
	"time"
)

//go:embed files
var files embed.FS

func getIps() []string {
	ips := make([]string, 0)
	ifaces, err := net.Interfaces()
	if err != nil {
		panic(err)
	}
	for _, i := range ifaces {
		addrs, err := i.Addrs()
		if err != nil {
			panic(err)
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip.To4() != nil && (ip.IsPrivate() || ip.IsLoopback()) {
				ips = append(ips, ip.String())
			}
		}
	}
	return ips
}

func main() {
	exploit, err := fs.Sub(files, "files/exploit")
	if err != nil {
		log.Println("Couldn't find exploit folder")
		panic(err)
	}
	payloadFilePath := ""

	func() {
		fs.WalkDir(files, "files/payload", func(path string, d fs.DirEntry, err error) error {
			if !d.IsDir() && strings.HasSuffix(d.Name(), ".bin") {
				payloadFilePath = path
			}
			return nil
		})
	}()

	if payloadFilePath == "" {
		panic("Couldn't find payload 😱")
	}

	send := func(ip string) {
		log.Printf("Payload: %s\n", payloadFilePath)
		log.Printf("Sending payload to : tcp://%s:%s\n", ip, "9020")

		address := net.JoinHostPort(ip, "9020")
		conn, err := net.DialTimeout("tcp", address, 3*time.Second)
		if err != nil {
			log.Printf("failed to connect: %s\n", err)
		}
		defer conn.Close()

		conn.SetWriteDeadline(time.Now().Add(time.Second * 10))
		fileB, err := fs.ReadFile(files, payloadFilePath)
		if err != nil {
			log.Printf("failed to open payload: %s, %s\n", payloadFilePath, err)
		}

		_, err = conn.Write(fileB)
		if err != nil {
			log.Printf("failed to send file: %s\n", err)
		}
	}

	http.Handle("/", http.FileServerFS(exploit))
	http.HandleFunc("/log/", func(w http.ResponseWriter, r *http.Request) {
		ip := strings.Split(r.RemoteAddr, ":")[0]
		go send(ip)
		w.Write([]byte("OK"))
	})

	port := 1337

	for _, u := range getIps() {
		log.Printf("Serving at http://%s:%v/\n", u, port)
	}

	err = http.ListenAndServe(fmt.Sprintf(":%d", port), nil)
	if err != nil {
		panic(err)
	}
}
