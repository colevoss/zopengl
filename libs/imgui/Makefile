SCRIPTS_DIR="./scripts"

.PHONY: sync dear_bindings copy_files clean_include

all: sync dear_bindings copy_files

sync:
	@$(SCRIPTS_DIR)/sync_repos.sh

dear_bindings:
	@$(SCRIPTS_DIR)/run_dear_bindings.sh

copy_files:
	@$(SCRIPTS_DIR)/copy_dear_imgui.sh

clean_include:
	@rm -rf ./include
