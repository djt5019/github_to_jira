ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

build:
	docker build -t gh .

run: build
	docker run -v ${ROOT_DIR}:/var/www --rm -i -t gh ruby /var/www/app.rb
