# aglo-cli

![This is an image](aglo_logo.svg)

## Installation

* Install script:
```
make install
```

* Create aglo.config.yml or generate it with ```aglo-cli init```
* Configure aglo.config.yml

## Configuration

Edit aglo.config.yml:

* sources *[required]* - (array of strings) folders to scan for strings
* include *[optional]* - (array of strings) use specific strings files only, if not defined, then all strings files will be scanned
* content *[required]* - (string) output folder for content department
* content_file *[optional]* - (string) name of strings file used by content department (by default is 'Localizable')
* locales *[optional]* - list (array of strings) of locales to use (by default all)
* clone_locale *[optional]* - (hash table) sets locales to be cloned from another locales

## Usage

To see all supported commands just run:

```
aglo-cli
```

## Author

* Siarhei Ladzeika <sergey.ladeiko@gmail.com>

## LICENSE

See [LICENSE](LICENSE)
