module Lumberjack
  class Device
    # This is an abstract class for a device that appends entries to a file and periodically archives
    # the existing file and starts a one. Subclasses must implement the roll_file? and archive_file_name
    # methods.
    class RollingLogFile < LogFile
      attr_reader :path
      
      def initialize(path, options = {})
        @path = File.expand_path(path)
        super(path, options)
        @file_inode = stream.lstat.ino rescue nil
      end
      
      # Returns the full path to the file that the log will be archived to. The file name should
      # change after the file is rolled. The log file will be renamed when it is rolled, so the
      # archive name must exist on the same file system as the log file.
      def archive_file_name
        raise NotImplementedError
      end
      
      # Return +true+ if the file should be rolled.
      def roll_file?
        raise NotImplementedError
      end
      
      protected
      
      # This method will be called after a file has been rolled. Subclasses can
      # implement code to reset the state of the device. This method is thread safe.
      def after_roll
      end
      
      # Handle rolling the file before flushing.
      def before_flush # :nodoc:
        path_inode = File.lstat(path).ino rescue nil
        if path_inode != @file_inode
          @file_inode = path_inode
          reopen_file
        else
          roll_file! if roll_file?
        end
      end

      private

      def reopen_file
        old_stream = stream
        self.stream = File.open(path, 'a')
        stream.sync = true
        @file_inode = stream.lstat.ino rescue nil
        old_stream.close
      end
      
      # Roll the log file by renaming it to the archive file name and then re-opening a stream to the log
      # file path. Rolling a file is safe in multi-threaded or multi-process environments.
      def roll_file! #:nodoc:
        do_once(stream) do
          archive_file = archive_file_name
          stream.flush
          current_inode = File.stat(path).ino rescue nil
          if @file_inode && current_inode == @file_inode && !File.exist?(archive_file)
            begin
              File.rename(path, archive_file)
              after_roll
            rescue SystemCallError
              # Ignore rename errors since it indicates the file was already rolled
            end
          end
        end
        reopen_file
      rescue => e
        STDERR.write("Failed to roll file #{path}: #{e.inspect}\n#{e.backtrace.join("\n")}\n")
      end
    end
    
    def do_once(file)
      begin
        file.flock(File::LOCK_EX)
      rescue SystemCallError
        # Most likely can't lock file because the stream is closed
        return
      end
      begin
        verify = file.lstat rescue nil
        # Execute only if the file we locked is still the same one that needed to be rolled
        yield if verify && verify.ino == @file_inode && verify.size > 0
      ensure
        stream.flock(File::LOCK_UN) rescue nil
      end
    end
  end
end