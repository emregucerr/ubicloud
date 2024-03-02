# frozen_string_literal: true

require "rubygems/package"
require "stringio"

class Prog::InstallRhizome < Prog::Base
  subject_is :sshable

  label def start
    raise "target_folder is undefined or empty" if frame["target_folder"].nil? || frame["target_folder"].empty?
    if !frame["install_specs"] && !frame["target_folder"].empty?
      cleanup_specs_cmd = "find #{Config.root}/rhizome/#{frame["target_folder"]} -name '*_spec.rb' -exec rm {} \\;"
      sshable.cmd(cleanup_specs_cmd)
    end
    tar = StringIO.new
    Gem::Package::TarWriter.new(tar) do |writer|
      base = Config.root + "/rhizome"
      Dir.glob(["Gemfile", "Gemfile.lock", "common/**/*", "#{frame["target_folder"]}/**/*"], base: base).map do |file|
        next if !frame["install_specs"] && file.end_with?("_spec.rb")
        full_path = base + "/" + file
        stat = File.stat(full_path)
        if stat.directory?
          writer.mkdir(file, stat.mode)
        elsif stat.file?
          writer.add_file(file, stat.mode) do |tf|
            File.open(full_path, "rb") do
              IO.copy_stream(_1, tf)
            end
          end
        else
          # :nocov:
          fail "BUG"
          # :nocov:
        end
      end
    end

    payload = tar.string.freeze
    sshable.cmd("tar xf -", stdin: payload)

    hop_install_gems
  end

  label def install_gems
    sshable.cmd("bundle config set --local path vendor/bundle")
    sshable.cmd("bundle install")
    pop "installed rhizome"
  end
end
