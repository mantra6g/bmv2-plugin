package handlers

import (
	"github.com/mantra6g/bmv2-plugin/pkg/api"
	p4switch "github.com/mantra6g/bmv2-plugin/pkg/p4switch"

	"github.com/go-logr/logr"
	"google.golang.org/grpc"
)

// Driver holds the P4Runtime client and gRPC connection.
type Driver struct {
	Switch         *p4switch.SwitchClient
	Conn           *grpc.ClientConn
	CurrentProgram *api.P4Program
	Log            logr.Logger
}
