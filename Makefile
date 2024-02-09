MAKEFLAGS += --no-print-directory

hydrate:
	OPENAI_API_MODEL=gpt-3.5-turbo-0125 go run hydrate.go

# Unit tests
test-sh-unit:
	shellspec --shell zsh --pattern "**/unit_spec.sh"

test-sh-integration:
	shellspec --shell zsh --pattern "**/integration_spec.sh"

test-go-unit:
	go test ./...

test-unit:
	@$(MAKE) test-go-unit
	@$(MAKE) test-sh-unit

test-unit-watch:
	nodemon -e zsh,sh,json,go -w ai.zsh -w "**/*" -x 'make test-unit || exit 1'

# Integration tests
test-integration:
	@$(MAKE) test-sh-integration

# Aliasing these for convenience. Any watchers shouldn't hit any APIs, and
# someone's first inclination to run `make test` also shouldn't.
test:
	@$(MAKE) test-unit

test-watch:
	@$(MAKE) test-unit-watch

# The big boy
test-all:
	@$(MAKE) test-unit
	@$(MAKE) test-integration

# Unfortunately shellspec requires the --focus flag to be able to see focused
# tests, but if there are none, will error if flag is provided.
test-sh-focus:
	shellspec --shell zsh --focus --pattern "**/*_spec.sh"

test-sh-focus-watch:
	nodemon -e zsh,sh,json -w ai.zsh -w "**/*" -x 'make test-sh-focus || exit 1'

