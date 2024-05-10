package app

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/zeromicro/go-zero/core/conf"
    "github.com/zeromicro/go-zero/core/logx"
	"github.com/zeromicro/go-zero/core/service"
	"github.com/zeromicro/go-zero/rest"

	"{{ .Module }}/app/internal/config"
	"{{ .Module }}/app/internal/handler"
	"{{ .Module }}/app/internal/svc"
	"{{ .Module }}/app/middlewares"
)

func Start(cfgFile string) {
	var c config.Config
	conf.MustLoad(cfgFile, &c)
    // set up logger
    if err := logx.SetUp(c.Log.LogConf); err != nil {
        logx.Must(err)
    }

	ctx := svc.NewServiceContext(c)
	start(ctx)
}

func start(ctx *svc.ServiceContext) {
	// print log to console if Log.Mode is file or volume
	middlewares.PrintLogToConsole(ctx.Config)

	server := rest.MustNewServer(ctx.Config.Rest.RestConf)

	server.Use(middlewares.WrapResponse)

	// gw add routes
	handler.RegisterMyHandlers(server, ctx)

	// gw add api routes
	handler.RegisterHandlers(server, ctx)

	group := service.NewServiceGroup()
	group.Add(server)

	go func() {
		fmt.Printf("Starting rest server at %s:%d...\n", ctx.Config.Rest.Host, ctx.Config.Rest.Port)
		group.Start()
	}()

	signalHandler(ctx, group)
}

func signalHandler(ctx *svc.ServiceContext, serviceGroup *service.ServiceGroup) {
	// signal handler
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGHUP, syscall.SIGQUIT, syscall.SIGTERM, syscall.SIGINT)
	for {
		s := <-c
		switch s {
		case syscall.SIGQUIT, syscall.SIGTERM, syscall.SIGINT:
			fmt.Println("Waiting 1 second...\nStopping rpc server and gateway server")
			time.Sleep(time.Second)
			serviceGroup.Stop()
			return
		case syscall.SIGHUP:
		default:
			return
		}
	}
}
