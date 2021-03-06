require "fpm/source"
require "fileutils"
require "fpm/rubyfixes"
require "fpm/util"

class FPM::Source::Dir < FPM::Source
  def get_metadata
    self[:name] = File.basename(File.expand_path(root))
  end

  def make_tarball!(tar_path, builddir)
    if self[:prefix]
      # Trim leading '/' from prefix
      self[:prefix] = self[:prefix][1..-1] if self[:prefix] =~ /^\//

      # Prefix all files with a path if given.
      @paths.each do |path|
        # Trim @root (--chdir)
        if @root != "." and path.start_with?(@root)
          path = path[@root.size .. -1]
        end

        # Copy to self[:prefix] (aka --prefix)
        if File.directory?(path)
          # Turn 'path' into 'path/' so rsync copies it properly.
          path = "#{path}/" if path[-1,1] != "/"
          dest = "#{builddir}/tarbuild/#{self[:prefix]}/#{path}"
        else
          dest = "#{builddir}/tarbuild/#{self[:prefix]}/#{File.dirname(path)}"
        end

        ::FileUtils.mkdir_p(dest)
        rsync = ["rsync", "-a", path, dest]
        p rsync if $DEBUG
        safesystem(*rsync)

        # FileUtils.cp_r is pretty silly about how it copies files in some
        # cases (funky permissions, etc)
        # Use rsync instead..
        #FileUtils.cp_r(path, dest)
      end

      # Prefix paths with 'prefix' if necessary.
      if self[:prefix]
        @paths = @paths.collect { |p| File.join("/", self[:prefix], p) }
      end

      ::Dir.chdir("#{builddir}/tarbuild") do
        safesystem("ls #{builddir}/tarbuild") if $DEBUG
        tar(tar_path, ".")
      end
    else
      # Prefix everything with "./" as per the Debian way if needed ...
      path = paths[0].match(/^(\.\/|\.)/) ? paths[0] : "./%s" % paths[0]
      tar(tar_path, path)
    end

    # TODO(sissel): Make a helper method.
    safesystem(*["gzip", "-f", tar_path])
  end # def make_tarball!
end # class FPM::Source::Dir
