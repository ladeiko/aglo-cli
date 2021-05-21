#!/usr/bin/env ruby

#
# Siarhei Ladzeika <sergey.ladeiko@gmail.com> 2020-present
#
# MIT License
# Copyright (c) 2021-present Siarhei Ladzeika

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require "yaml"

begin
  require "dry/cli"
rescue LoadError
  abort "FAILED: Please install required dry/cli package with: gem install dry-cli"
end

require "fileutils"

VERSION = "1.0.0"
CONFIG_NAME = "aglo.config.yml"
DEFAULT_CONTENT_FILE = "Localizable"

puts "aglo-cli v#{VERSION} (c) by Siarhei Ladzeika <sergey.ladeiko@gmail.com>"
puts ""

system "which aglo-cli >/dev/null"
if $?.exitstatus != 0
  puts "aglo-cli not found on local system, therefore will be installed"
  system "(rm -rf /tmp/aglo-cli && mkdir -p /tmp/aglo-cli && cd /tmp/aglo-cli && git clone https://github.com/ladeiko/aglo-cli.git && cd aglo-cli && make install && rm -rf /tmp/aglo-cli)"
  if $?.exitstatus != 0
    exit 1
  end
end

def shellescape(str)
  str = str.to_s

  # An empty argument will be skipped, so return empty quotes.
  return "''".dup if str.empty?

  str = str.dup

  # Treat multibyte characters as is.  It is the caller's responsibility
  # to encode the string in the right encoding for the shell
  # environment.
  str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\\\\\1")

  # A LF cannot be escaped with a backslash because a backslash + LF
  # combo is regarded as a line continuation and simply ignored.
  str.gsub!(/\n/, "'\n'")

  return str
end

INIT_CONFIG = %{
sources:                        # Folders to scan for developer strings file
    - Sources
include: []                     # Names if strings files to scan, if not defined or empty, then all of them will be scanned
content: Localization           # Folder relative to config where content file is located, e.g: ./Localization
content_file: Localizable       # name of file in contents folder, by default is Localizable
locales:                        # List of locales to scan
    - ru
    - en
no_merge: false
clone_locale:
    zh: ru                      # will clone ru -> zh
}

module AgloCLI
  class Config
    def initialize(config_file)
      config_dir = config_file.nil? ? Dir.pwd : File.expand_path(config_file)
      config_path = Dir.exist?(config_dir) ? File.join(config_dir, CONFIG_NAME) : config_dir

      if !File.exist?(config_path)
        abort "ERROR: Configuration file '#{config_path}' not found"
      end

      config_dir = File.dirname(config_path)
      config = YAML.load(File.read(config_path))

      if !config["sources"].kind_of?(Array)
        abort "ERROR: Invalid config 'sources' (should be array of strings)"
      end

      if config["sources"].length == 0
        abort "ERROR: Invalid config 'sources' (should contain at least one string)"
      end

      if !config["include"].nil? && !config["include"].kind_of?(Array)
        abort "ERROR: Invalid config 'include' (should be array of strings)"
      end

      if !config["locales"].nil? && !config["locales"].kind_of?(Array)
        abort "ERROR: Invalid config 'locales' (should be array of strings)"
      end

      if !config["content"].kind_of?(String)
        abort "ERROR: Invalid config 'content' (should be string)"
      end

      if !config["content_file"].nil?
        if !config["content_file"].kind_of?(String)
          abort "ERROR: Invalid config 'content_file' (should be string)"
        end
        value = config["content_file"]
        if !value.empty?
          @content_file = value.strip
        else
          @content_file = DEFAULT_CONTENT_FILE
        end
      else
        @content_file = DEFAULT_CONTENT_FILE
      end

      if !config["clone_locale"].nil?
        if !config["clone_locale"].is_a?(Hash)
          abort "ERROR: Invalid config 'clone_locale' (should be array of dictionary)"
        end

        @clone_locale = config["clone_locale"]
      end

      @content = config["content"].kind_of?(Array) ? config["content"].to_enum(:each_with_index).map { |v, i| "#{File.join(config_dir, v)}" }.join("|") : File.join(config_dir, config["content"])
      @sources = config["sources"].kind_of?(Array) ? config["sources"].to_enum(:each_with_index).map { |v, i| "#{File.join(config_dir, v)}" }.join("|") : File.join(config_dir, config["sources"])

      filenames_options = []
      if config["include"].kind_of?(Array) && config["include"].length > 0
        config["include"].each do |v|
          filenames_options << "--filename"
          filenames_options << v
        end
      end

      locales_options = []
      if config["locales"].kind_of?(Array) && config["locales"].length > 0
        config["locales"].each do |v|
          locales_options << "--locale"
          locales_options << v
        end
      end

      @no_merge = false

      if [true, false].include?(config["no_merge"])
        @no_merge = config["no_merge"]
      end

      @filenames_options = filenames_options
      @locales_options = locales_options
    end

    attr_reader :sources
    attr_reader :content
    attr_reader :filenames_options
    attr_reader :locales_options
    attr_reader :clone_locale
    attr_reader :content_file
    attr_reader :no_merge
  end
end

module AgloCLI
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Version < Dry::CLI::Command
        desc "Print version"

        def call(*)
          puts VERSION
        end
      end

      class Prettify < Dry::CLI::Command
        desc "Prettify project strings files (sort keys, etc...)"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        def call(config_path: nil, **options)
          config = AgloCLI::Config.new(config_path)

          system []
                   .concat(["aglo-cli"])
                   .concat(["addAbsentKeys", "--verbose"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0

          system []
                   .concat(["aglo-cli"])
                   .concat(["sortKeys", "--verbose", "--case-insensitive"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0

          system []
                   .concat(["aglo-cli"])
                   .concat(["prettify", "--verbose"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0

          if !config.clone_locale.nil? && !config.clone_locale.empty?
            config.clone_locale.each do |target, source|
              system []
                       .concat(["aglo-cli"])
                       .concat(["cloneLocale", "--verbose"])
                       .concat([config.filenames_options, config.locales_options])
                       .concat(["'" + config.sources + "'"])
                       .concat([source, target])
                       .flatten
                       .join(" ")
              abort("FAILED") if $?.exitstatus != 0
            end
          end
        end
      end

      class Push < Dry::CLI::Command
        desc "Push new keys from project source strings files into content single Localizable.strings"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"
        option :override, values: %w[none all keys], default: "none", desc: "Override: none (default, all, keys)"

        def call(config_path: nil, override:, **options)
          config = AgloCLI::Config.new(config_path)

          if !config.clone_locale.nil? && !config.clone_locale.empty?
            config.clone_locale.each do |target, source|
              system []
                       .concat(["aglo-cli"])
                       .concat(["cloneLocale", "--verbose"])
                       .concat([config.filenames_options, config.locales_options])
                       .concat(["'" + config.sources + "'"])
                       .concat([source, target])
                       .flatten
                       .join(" ")
              abort("FAILED") if $?.exitstatus != 0
            end
          end
          system []
                   .concat(["aglo-cli"])
                   .concat(["removeDuplicateKeys", "--verbose"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["zipKeys", "--verbose", "--update-comments"])
                   .concat(["--sort", "--case-insensitive"])
                   .concat(["--detect-tags"])
                   .concat(override == "all" ? ["--force"] : (override == "keys" ? ["--override-keys", "--merge"] : ["--merge"]))
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'", "'" + config.content + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class Pull < Dry::CLI::Command
        desc "Pull translations from content Localizable.strings into project strings files"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        def call(config_path: nil, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["unzipKeys", "--verbose", "--detect-tags", "--ignore-invalid-source-keys"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.content + "'", "'" + config.sources + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0

          if !config.clone_locale.nil? && !config.clone_locale.empty?
            config.clone_locale.each do |target, source|
              system []
                       .concat(["aglo-cli"])
                       .concat(["cloneLocale", "--verbose"])
                       .concat([config.filenames_options, config.locales_options])
                       .concat(["'" + config.sources + "'"])
                       .concat([source, target])
                       .flatten
                       .join(" ")
              abort("FAILED") if $?.exitstatus != 0
            end
          end
        end
      end

      class Sync < Dry::CLI::Command
        desc "Sync new keys from project source strings files into content single Localizable.strings and pull localizations"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        def call(config_path: nil, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["sync", "--verbose"])
                   .concat(config.no_merge ? ["--no-merge"] : [])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'", "'" + config.content + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class Doctor < Dry::CLI::Command
        desc "Fixes some issues in project strings files"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        def call(config_path: nil, **options)
          config = AgloCLI::Config.new(config_path)

          system []
                   .concat(["aglo-cli"])
                   .concat(["removeDuplicateKeys", "--verbose"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0

          if !config.clone_locale.nil? && !config.clone_locale.empty?
            config.clone_locale.each do |target, source|
              system []
                       .concat(["aglo-cli"])
                       .concat(["cloneLocale", "--verbose"])
                       .concat([config.filenames_options, config.locales_options])
                       .concat(["'" + config.sources + "'"])
                       .concat([source, target])
                       .flatten
                       .join(" ")
              abort("FAILED") if $?.exitstatus != 0
            end
          end
        end
      end

      class Validate < Dry::CLI::Command
        desc "Validate project strings files"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        def call(config_path: nil, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["validate"])
                   .concat([config.filenames_options, config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class SetValue < Dry::CLI::Command
        desc "Set value for specified key"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"
        argument :value, required: true, desc: "New value for key"

        def call(config_path: nil, filename:, key:, value:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["setValue"])
                   .concat(["--create-key", "--verbose", "--unescape"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key), shellescape(value)])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class SetComment < Dry::CLI::Command
        desc "Set comment for specified key"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"
        argument :comment, required: true, desc: "New comment for key"

        def call(config_path: nil, filename:, key:, comment:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["setComment"])
                   .concat(["--verbose", "--unescape"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key), shellescape(comment)])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class RenameKey < Dry::CLI::Command
        desc "Rename specified key"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"
        argument :new_key, required: true, desc: "New name of key"

        def call(config_path: nil, filename:, key:, new_key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["renameKey"])
                   .concat(["--unescape", "--fail-if-absent"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key), shellescape(new_key)])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["renameKey"])
                   .concat(["--unescape"])
                   .concat(["--filename", config.content_file])
                   .concat([config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .concat([shellescape("#{filename}.strings:#{key}"), shellescape("#{filename}.strings:#{new_key}")])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class MoveKey < Dry::CLI::Command
        desc "Move key from one to another strings file"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :source_filename, required: true, desc: "Source strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"
        argument :destination_filename, required: true, desc: "Destination strings file name (without extension)"
        argument :new_key, desc: "New name of key (if you want to rename it while move)"

        def call(config_path: nil, source_filename:, key:, destination_filename:, **options)
          if source_filename == destination_filename
            abort "FAILED: Destination and source files should be different ones"
          end

          new_key = options.fetch(:new_key, nil)

          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["moveKey"])
                   .concat(["--add-locales"])
                   .concat(["--unescape"])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(source_filename), shellescape(destination_filename), shellescape(key), (new_key.nil? || new_key.empty?) ? nil : shellescape(new_key)])
                   .flatten
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["renameKey"])
                   .concat(["--unescape"])
                   .concat(["--sort", "--case-insensitive"])
                   .concat(["--filename", config.content_file])
                   .concat([config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .concat([shellescape("#{source_filename}.strings:#{key}"), shellescape("#{destination_filename}.strings:#{new_key.nil? ? key : new_key}")])
                   .flatten
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class CopyKey < Dry::CLI::Command
        desc "Copy key from one to another strings file"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :source_filename, required: true, desc: "Source strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"
        argument :destination_filename, required: true, desc: "Destination strings file name (without extension)"
        argument :new_key, desc: "New name of key (if you want to rename it while move)"

        def call(config_path: nil, source_filename:, key:, destination_filename:, **options)
          new_key = options.fetch(:new_key, nil)

          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["copyKey"])
                   .concat(["--unescape"])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(source_filename),
                            shellescape(key),
                            shellescape(destination_filename),
                            (new_key.nil? || new_key.empty?) ? nil : shellescape(new_key)])
                   .flatten
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class AddKey < Dry::CLI::Command
        desc "Adds new key to specified strings file"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"

        def call(config_path: nil, filename:, key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["addKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class RejectKey < Dry::CLI::Command
        desc "Mark specified key as untranslated (adds '#' at the beginning)"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"

        def call(config_path: nil, filename:, key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["clearKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", shellescape(filename)])
                   .concat(["--add-prefix-only"])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["clearKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", config.content_file])
                   .concat(["--add-prefix-only"])
                   .concat([config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .concat([shellescape("#{filename}.strings:#{key}")])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class ClearKey < Dry::CLI::Command
        desc "Clear value and mark specified key as untranslated (sets value to '#')"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"

        def call(config_path: nil, filename:, key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["clearKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["clearKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", config.content_file])
                   .concat([config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .concat([shellescape("#{filename}.strings:#{key}")])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class DeleteKey < Dry::CLI::Command
        desc "Delete specified key"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"

        def call(config_path: nil, filename:, key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["deleteKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["deleteKeys"])
                   .concat(["--unescape"])
                   .concat(["--filename", config.content_file])
                   .concat([config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .concat([shellescape("#{filename}.strings:#{key}")])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class ApproveKey < Dry::CLI::Command
        desc "Mark specified key as translated (removes '#' at the beginning)"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"
        option :ignore_empty, type: :boolean, default: false, desc: "Should we ignore empty values"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"

        def call(config_path: nil, filename:, key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["makeKeysTranslated"])
                   .concat(["--unescape", "--ignore-empty"])
                   .concat(["--filename", shellescape(filename)])
                   .concat([options.fetch(:ignore_empty) ? "--ignore-empty" : nil])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
          system []
                   .concat(["aglo-cli"])
                   .concat(["makeKeysTranslated"])
                   .concat(["--unescape", "--ignore-empty"])
                   .concat(["--filename", config.content_file])
                   .concat([options.fetch(:ignore_empty) ? "--ignore-empty" : nil])
                   .concat([config.locales_options])
                   .concat(["'" + config.content + "'"])
                   .concat([shellescape("#{filename}.strings:#{key}")])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class LinkKey < Dry::CLI::Command
        desc "Link specified key to another key translation"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"
        argument :target_filename, required: true, desc: "Target strings file name (without extension)"
        argument :target_key, required: true, desc: "Name of the target key"

        def call(config_path: nil, filename:, key:, target_filename:, target_key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["linkKey"])
                   .concat(["--unescape"])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(filename)])
                   .concat([shellescape(key)])
                   .concat([shellescape(target_filename)])
                   .concat([shellescape(target_key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class UnlinkKey < Dry::CLI::Command
        desc "Unlink specified key translation"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :key, required: true, desc: "Name of the key"

        def call(config_path: nil, filename:, key:, **options)
          config = AgloCLI::Config.new(config_path)
          system []
                   .concat(["aglo-cli"])
                   .concat(["unlinkKey"])
                   .concat(["--unescape"])
                   .concat([config.locales_options])
                   .concat(["'" + config.sources + "'"])
                   .concat([shellescape(filename)])
                   .concat([shellescape(key)])
                   .compact
                   .join(" ")
          abort("FAILED") if $?.exitstatus != 0
        end
      end

      class ConnectKey < Dry::CLI::Command
        desc "Connects key from content to developer one"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :key_to_connect, required: true, desc: "Name of the current key"
        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :developer_key, required: true, desc: "Name of the developer key"

        def call(config_path: nil, key_to_connect:, filename:, developer_key:, **options)
          config = AgloCLI::Config.new(config_path)
          cmd = []
            .concat(["aglo-cli"])
            .concat(["renameKey"])
            .concat(["--unescape"])
            .concat(["--verbose", "--fail-if-absent"])
            .concat(["--filename", config.content_file])
            .concat([config.locales_options])
            .concat(["'" + config.content + "'"])
            .concat([shellescape(key_to_connect)])
            .concat([shellescape("#{filename}.strings:#{developer_key}")])
            .compact
            .join(" ")
          system cmd
          abort("#{cmd} FAILED") if $?.exitstatus != 0
        end
      end

      class BalanceKeys < Dry::CLI::Command
        desc "Adds missing keys in locales in developer files (e.g: if some key presents in RU, but not in EN, then key will be added to EN)"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        argument :filename, required: true, desc: "Strings file name (without extension)"
        argument :developer_key, required: true, desc: "Name of the developer key to be balanced"

        def call(config_path: nil, filename:, developer_key:, **options)
          config = AgloCLI::Config.new(config_path)
          cmd = []
            .concat(["aglo-cli"])
            .concat(["balanceKeys"])
            .concat(["--unescape"])
            .concat(["--filename", filename])
            .concat([config.locales_options])
            .concat(["'" + config.sources + "'"])
            .concat([shellescape(developer_key)])
            .compact
            .join(" ")
          system cmd
          abort("#{cmd} FAILED") if $?.exitstatus != 0
        end
      end

      class Init < Dry::CLI::Command
        desc "Creates initial config"

        option :config_path, desc: "Configuration file (#{CONFIG_NAME} by default)"

        def call(config_path: nil, **options)
          path = config_path
          if path.nil?
            path = Dir.pwd
          end
          if !path.end_with?(".yml")
            path = File.join(path, CONFIG_NAME)
          end

          if File.exist?(path)
            abort("File #{path} already exists")
          end

          File.write(path, INIT_CONFIG)
          abort("#{cmd} FAILED") if $?.exitstatus != 0
        end
      end

      register "version", Version, aliases: ["v", "-v", "--version"]
      register "push", Push
      register "pull", Pull
      register "sync", Sync
      register "validate", Validate
      register "set-value", SetValue, aliases: ["setValue"]
      register "set-comment", SetComment, aliases: ["setComment"]
      register "rename-key", RenameKey, aliases: ["renameKey"]
      register "move-key", MoveKey, aliases: ["moveKey"]
      register "copy-key", CopyKey, aliases: ["copyKey"]
      register "add-key", AddKey, aliases: ["addKey"]
      register "balance-key", BalanceKeys, aliases: ["balance-keys", "balanceKey", "balanceKeys"]
      register "reject-key", RejectKey, aliases: ["rejectKey"]
      register "clear-key", ClearKey, aliases: ["clearKey"]
      register "delete-key", DeleteKey, aliases: ["deleteKey"]
      register "approve-key", ApproveKey, aliases: ["approveKey"]
      register "link-key", LinkKey, aliases: ["linkKey"]
      register "unlink-key", UnlinkKey, aliases: ["unlinkKey"]
      register "connect-key", ConnectKey, aliases: ["connectKey"]
      register "prettify", Prettify
      register "doctor", Doctor
      register "init", Init
    end # module Commands
  end # module CLI
end # module AgloCLI

Dry::CLI.new(AgloCLI::CLI::Commands).call
