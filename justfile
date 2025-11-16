# justfile - Build commands for NeoTODO plugin

# Run all tests
test:
    nvim --headless -u tests/minimal_init.lua -c "lua require('plenary.test_harness').test_directory('tests/', { minimal_init = 'tests/minimal_init.lua' })"

# Run tests on file change (requires watchexec or entr)
test-watch:
    watchexec -e lua just test
