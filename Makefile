NAME    := unsee
VERSION := $(shell git describe --tags --always --dirty='-dev')

# Alertmanager instance used when running locally, points to mock data
ALERTMANAGER_URI := https://raw.githubusercontent.com/cloudflare/unsee/master/mock
# Listen port when running locally
PORT := 8080

SOURCES       := $(wildcard *.go) $(wildcard */*.go)
ASSET_SOURCES := $(wildcard assets/*/* assets/*/*/*)

GO_BINDATA_MODE := prod
GIN_DEBUG := false
ifdef DEBUG
	GO_BINDATA_FLAGS = -debug
	GO_BINDATA_MODE  = debug
	GIN_DEBUG = true
	DOCKER_ARGS = -v $(CURDIR)/assets:$(CURDIR)/assets:ro
endif

.DEFAULT_GOAL := $(NAME)

.build/deps.ok:
	go get -u github.com/jteeuwen/go-bindata/...
	go get -u github.com/elazarl/go-bindata-assetfs/...
	go get -u github.com/golang/lint/golint
	mkdir -p .build
	touch $@

.build/bindata_assetfs.%:
	mkdir -p .build
	rm -f .build/bindata_assetfs.*
	touch $@

bindata_assetfs.go: .build/deps.ok .build/bindata_assetfs.$(GO_BINDATA_MODE) $(ASSET_SOURCES)
	go-bindata-assetfs $(GO_BINDATA_FLAGS) -prefix assets -nometadata assets/templates/... assets/static/...

$(NAME): .build/deps.ok bindata_assetfs.go $(SOURCES)
	go build -ldflags "-X main.version=$(VERSION)"

.PHONY: clean
clean:
	rm -fr .build $(NAME)

.PHONY: run
run: $(NAME)
	ALERTMANAGER_URI=$(ALERTMANAGER_URI) \
	COLOR_LABELS_UNIQUE="instance cluster" \
	COLOR_LABELS_STATIC="job" \
	DEBUG="$(GIN_DEBUG)" \
	PORT=$(PORT) \
	./$(NAME)

.PHONY: docker-image
docker-image: bindata_assetfs.go
	docker build --build-arg VERSION=$(VERSION) -t $(NAME):$(VERSION) .

.PHONY: run-docker
run-docker: docker-image
	@docker rm -f $(NAME) || true
	docker run \
	    --name $(NAME) \
			$(DOCKER_ARGS) \
	    -e ALERTMANAGER_URI=$(ALERTMANAGER_URI) \
			-e COLOR_LABELS_UNIQUE="instance cluster" \
			-e COLOR_LABELS_STATIC="job" \
			-e DEBUG="$(GIN_DEBUG)" \
	    -e PORT=$(PORT) \
	    -p $(PORT):$(PORT) \
	    $(NAME):$(VERSION)

.PHONY: lint
lint: .build/deps.ok
	@golint ./... | (egrep -v "^vendor/|^bindata_assetfs.go" || true)

.PHONY: test
test: lint bindata_assetfs.go
	@go test -cover `go list ./... | grep -v /vendor/`

.build/vendor.ok:
	go get -u github.com/kardianos/govendor
	mkdir -p .build
	touch $@

.PHONY: vendor
vendor: .build/vendor.ok
	govendor remove +u
	govendor fetch +m +e

.PHONY: vendor-update
vendor-update: .build/vendor.ok
	govendor fetch +v

#======================== asset helper targets =================================

ASSETS_DIR := $(CURDIR)/assets/static/managed
CDNJS_PREFIX := https://cdnjs.cloudflare.com/ajax/libs

%.js:
	$(eval VERSION := $(word 2, $(subst /, ,$@)))
	$(eval DIRNAME := $(shell dirname $@))
	$(eval BASENAME := $(shell basename $@))
	$(eval MAPPATH := $(@:.js=.map))
	$(eval MAPFILE := $(shell basename $(MAPPATH)))
	$(eval OUTPUT := $(ASSETS_DIR)/js/$(VERSION)-$(BASENAME))
	@echo Fetching js asset $@
	@mkdir -p $(ASSETS_DIR)/js
	@curl --fail -so $(OUTPUT) $(CDNJS_PREFIX)/$@ || (rm -f $(OUTPUT) && exit 1)
	@( \
	    export MAP=`grep sourceMappingURL $(OUTPUT) | cut -d = -f 2`; \
		(test -n "$$MAP" && echo "+ Fetching js map $${MAP}" && (curl --fail -so $(ASSETS_DIR)/js/$${MAP} $(CDNJS_PREFIX)/$(DIRNAME)/$$MAP || rm -f $(ASSETS_DIR)/js/$${MAP})); \
		(test -z "$$MAP" && echo "+ Fetching js map $(MAPPATH)" && (curl --fail -so $(ASSETS_DIR)/js/$(MAPFILE) $(CDNJS_PREFIX)/$(MAPPATH) || rm -f $(ASSETS_DIR)/js/$(MAPFILE)) || true); \
	    ) || true
	@echo $(VERSION)-$(shell basename $@) >> $(ASSETS_DIR)/js/assets.txt

%.css:
	$(eval VERSION := $(word 2, $(subst /, ,$@)))
	$(eval OUTPUT := $(ASSETS_DIR)/css/$(VERSION)-$(shell basename $@))
	@echo Fetching css asset $@
	@mkdir -p $(ASSETS_DIR)/css
	@curl --fail -so $(OUTPUT) $(CDNJS_PREFIX)/$@ || (rm -f $(OUTPUT) && exit 1)
	@echo $(VERSION)-$(shell basename $@) >> $(ASSETS_DIR)/css/assets.txt

font-awesome/4.7.0/fonts/%:
	$(eval OUTPUT := $(ASSETS_DIR)/fonts/$(shell basename $@))
	@echo Fetching fonts asset $@
	@mkdir -p $(ASSETS_DIR)/fonts
	@curl --fail -so $(OUTPUT) $(CDNJS_PREFIX)/$@ || (rm -f $(OUTPUT) && exit 1)

.PHONY: clean-assets
clean-assets:
	@git rm -f $(ASSETS_DIR)/*/* >/dev/null 2>&1 || true

.PHONY: assets
assets: clean-assets
# jquery, for everything
assets: jquery/2.2.4/jquery.min.js
# moment, for timestamp parsing and printing
assets: moment.js/2.17.1/moment.min.js
# favico, for adding alert counter to the favico
assets: favico.js/0.3.10/favico.min.js
# fontawesome, for ui icons
assets: font-awesome/4.7.0/css/font-awesome.min.css
assets: font-awesome/4.7.0/fonts/fontawesome-webfont.eot
assets: font-awesome/4.7.0/fonts/fontawesome-webfont.svg
assets: font-awesome/4.7.0/fonts/fontawesome-webfont.ttf
assets: font-awesome/4.7.0/fonts/fontawesome-webfont.woff
assets: font-awesome/4.7.0/fonts/fontawesome-webfont.woff2
assets: font-awesome/4.7.0/fonts/FontAwesome.otf
# bootstrap & bootstrap switch, for ui
assets: twitter-bootstrap/3.3.7/js/bootstrap.min.js
assets: bootswatch/3.3.7/flatly/bootstrap.min.css
assets: bootstrap-switch/3.3.2/js/bootstrap-switch.min.js
assets: bootstrap-switch/3.3.2/css/bootstrap3/bootstrap-switch.min.css
# nprogress, for refresh progress bar
assets: nprogress/0.2.0/nprogress.min.js
assets: nprogress/0.2.0/nprogress.min.css
# tagsinput & typeahead, for filter bar and autocomplete
assets: bootstrap-tagsinput/0.8.0/bootstrap-tagsinput.min.js
assets: bootstrap-tagsinput/0.8.0/bootstrap-tagsinput.css
assets: typeahead.js/0.11.1/typeahead.bundle.min.js
assets: bootstrap-tagsinput/0.8.0/bootstrap-tagsinput-typeahead.css
# loaders.css, for animated spinners
assets: loaders.css/0.1.2/loaders.css.min.js
assets: loaders.css/0.1.2/loaders.min.css
# js-cookie, for preference state loading via cookies
assets: js-cookie/2.1.3/js.cookie.min.js
# underscore & haml, for template rendering in js
assets: underscore.js/1.8.3/underscore-min.js
assets: underscore.string/2.4.0/underscore.string.min.js
assets: clientside-haml-js/5.4/haml.js
# masonry, for grid layout
assets: masonry/4.1.1/masonry.pkgd.min.js
# copy to clipboard
assets: clipboard.js/1.5.16/clipboard.min.js
# sentry client
assets: raven.js/3.9.1/raven.min.js
# sha1 function used to generate id from string
assets: js-sha1/0.4.0/sha1.min.js
# allows selecting only visible elements
assets: is-in-viewport/2.4.2/isInViewport.min.js
assets:
	@git add $(ASSETS_DIR)/*/*
