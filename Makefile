.PHONY: build run clean

build:
	./build-app.sh

run: build
	open CamBar.app

clean:
	rm -rf .build CamBar.app
