.PHONY: test test-watch

test-unit:
	shellspec --shell zsh --pattern "**/ai_spec.sh"

test-integration:
	shellspec --shell zsh --pattern "**/ai_integration_spec.sh" --jobs 8

test-watch:
	nodemon -e zsh,sh,json -w ai.zsh -w "bin/**/*" -w "spec/**/*" -x 'make test-unit || exit 1'
