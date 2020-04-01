# Changelog

## v0.6.0

### Enhancements

  * enable running tests in current file

## v0.5.0

### Enhancements

  * enable jumping from test file to related file

## v0.4.1

### Bug fixes

  * don't set default-directory as persistent variable (make find-file etc. use buffer directory as context)
  * fail getting current spec if line doesn't contain a string

## v0.4.0

### Enhancements

  * add function that allows user to jump to spec file related to current buffers file

## v0.3.0

### Enhancements

  * allow running individual test using karma --grep option
  * add variable for filenames to ask saving for

## v0.2.0-dev (unreleased)

### Enhancements

  * `karma-mode` should also be enabled in `coffee-mode`.

## v0.1.0

### Enhancements

  * implement `karma-start`, `karma-start-single-run`, `karma-start-no-single-run` and `karma-run`
  * add default Keymap inside `js-mode` and `js2-mode`
