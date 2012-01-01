
require 'stringio'
require 'col'

module Whitestone

  # --------------------------------------------------------------section---- #
  #                                                                           #
  #                             Whitestone::Output                            #
  #                                                                           #
  #               Contains all code that writes to the console                #
  #                                                                           #
  # ------------------------------------------------------------------------- #

  class Output

    def initialize
      # @buf is the buffer into which we write details of errors and failures so
      # that they can be emitted to the console all together.
      @buf = StringIO.new
      # @@files is a means of printing lines of code in failure and error
      # details.
      @@files ||= Hash.new { |h,k| h[k] = File.readlines(k) rescue nil }
      @filter_backtrace_yn = true
    end

    def set_full_backtrace
      @filter_backtrace_yn = false
    end

    def Output.relative_path(path)
      @current_dir ||= Dir.pwd
      path.sub(@current_dir, '.')
    end



    ##
    # Print the name and result of each test, using indentation.
    # This must be done after execution is finished in order to get the tree
    # structure right.
    def display_test_by_test_result(top_level)
      pipe = "|"
      space = " "
      #empty_line = space + pipe + (space * 76) + pipe
      header     = Col[" +----- Report " + "-" * (77-14) + "+"].cb
      empty_line = Col[space, pipe, space * 76, pipe].fmt(:_, :cb, :_, :cb)
      line = lambda { |desc,c1,s1,result,c2,s2|
        padding = space * ( 77 - (1 + desc.size + result.size ) )
        Col.inline( space, :_,         pipe, :cb,      desc, [c1,s1], \
                    result, [c2,s2],   padding, :_,    pipe, :cb)
      }
      footer     = Col[" +#{'-'*76}+"].cb

      puts
      puts header

      tree_walk(top_level.tests) do |test, level|
        description = (space + space + "  " * level + test.description).ljust(67)
        description = description[0...67]
        colour1, style1 =
          case test.result
          when :pass  then [:_,        :_]
          when :fail  then [:red,      :bold]
          when :error then [:magenta,  :bold]
          when :blank then [:_,        :_]
          end
        result, colour2, style2 =
          case test.result
          when :pass  then ['PASS',  :green,   :bold]
          when :fail  then ['FAIL',  :red,     :bold]
          when :error then ['ERROR', :magenta, :bold]
          when :blank then ['-',     :green,   :bold]
          end
        result = "  " + result
        if level == 0
          puts empty_line
          colour1 = (test.passed? or test.blank?) ? :yellow : colour2
          style1  = :bold
        end
        puts line[description, colour1, style1, result, colour2, style2]
      end

      puts empty_line
      puts footer
    end

    # Yield each test and its children (along with the current level 0,1,2,...)
    # in depth-first order.
    def tree_walk(tests, level=0, &block)
      tests.each do |test|
        block.call(test, level)
        unless test.children.empty?
          tree_walk( test.children, level+1, &block )
        end
      end
    end
    private :tree_walk



    def display_details_of_failures_and_errors
      unless @buf.string.strip.empty?
        puts
        puts @buf.string
      end
    end



    # Prepares and displays a colourful summary message saying how many tests
    # have passed, failed and errored.
    def display_results_npass_nfail_nerror_etc(stats)
      npass      = stats[:pass]  || 0
      nfail      = stats[:fail]  || 0
      nerror     = stats[:error] || 0
      overall    = (nfail + nerror > 0) ? :FAIL : :PASS
      time       = stats[:time]
      assertions = stats[:assertions]

      overall_str    = overall.to_s.ljust(9)
      npass_str      = sprintf "#pass: %-6d",  npass
      nfail_str      = sprintf "#fail: %-6d",  nfail
      nerror_str     = sprintf "#error: %-6d", nerror
      assertions_str = sprintf "assertions: %-6d", assertions
      time_str       = sprintf "time: %3.3f", time

      overall_col    = (overall == :PASS)  ?  :green  :  :red
      npass_col      = :green
      nfail_col      = (nfail  > 0)  ?  :red      :  :green
      nerror_col     = (nerror > 0)  ?  :magenta  :  :green
      assertions_col = :white
      time_col       = :white

      coloured_info = Col.inline(
        overall_str,    [overall_col,    :bold],
        npass_str,      [npass_col,      :bold],
        nfail_str,      [nfail_col,      :bold],
        nerror_str,     [nerror_col,     :bold],
        assertions_str, [assertions_col, :bold],
        time_str,       [time_col,       :bold]
      )

      equals = Col["=" * 80].fmt [overall_col, :bold]
      nl = "\n"

      output = String.new.tap { |str|
        str << equals << nl
        str << " " << coloured_info << nl
        str << equals << nl
      }

      puts
      puts output
    end



    def report_failure(description, message, backtrace)
      message ||= "No message! #{__FILE__}:#{__LINE__}"
      bp = BacktraceProcessor.new(backtrace, @filter_backtrace_yn)

      # Determine the file and line number of the failed assertion, and extract
      # the code surrounding that line.
      file, line = bp.determine_file_and_lineno()
      code = extract_code(file, line)

      # Emit the failure report.
      @buf.puts
      @buf.puts Col["FAIL: #{description}"].rb
      @buf.puts code.___indent(4) if code
      @buf.puts message.___indent(2)
      @buf.puts "  Backtrace\n" + bp.backtrace.join("\n").___indent(4)
    end  # report_failure



    def report_uncaught_exception(description, exception, _calls, force_filter_bt=false)
      filter_yn = @filter_backtrace_yn || force_filter_bt
      bp = BacktraceProcessor.new(exception.backtrace, filter_yn)

      # Determine the current test file, the line number that triggered the
      # error, and extract the code surrounding that line.
      file, line = bp.determine_file_and_lineno(_calls)
      code = extract_code(file, line)

      # Emit the error report.
      @buf.puts
      @buf.puts Col("ERROR: #{description}").fmt(:mb)
      @buf.puts code.___indent(4) if code
      @buf.puts Col.inline("  Class:   ", :mb, exception.class, :yb)
      @buf.puts Col.inline("  Message: ", :mb, exception.message, :yb)
      @buf.puts "  Backtrace\n" + bp.backtrace.join("\n").___indent(4)
    end  # report_uncaught_exception



    def report_specification_error(e)
      puts
      puts "You have made an error in specifying one of your assertions."
      puts "Details below; can't continue; exiting."
      puts
      puts Col.inline("Message: ", :_, e.message, :yb)
      puts
      puts "Filtered backtrace:"
      filtered = BacktraceProcessor.new(e.backtrace, true).backtrace
      puts filtered.join("\n").___indent(2)
      puts
      puts "Full backtrace:"
      puts e.backtrace.join("\n").___indent(2)
      puts
    end



    def extract_code(file, line)
      return nil if file.nil? or line.nil? or file == "(eval)"
      if source = @@files[file]
        line = line.to_i
        radius = 2 # number of surrounding lines to show
        region1 = [line - radius, 1].max .. [line - 1, 1].max
        region2 = [line]
        region3 = [line + 1, source.length].min .. [line + radius, source.length].min

        # ensure proper alignment by zero-padding line numbers
        format = "%2s %0#{region3.last.to_s.length}d %s"

        pretty1 = region1.map { |n|
          format % [nil, n, source[n-1].chomp.___truncate(60)]
        }
        pretty2 = region2.map  { |n|
          string = format % ['=>', n, source[n-1].chomp.___truncate(60)]
          Col[string].fmt(:yb)
        }
        pretty3 = region3.map { |n|
          format % [nil, n, source[n-1].chomp.___truncate(60)]
        }
        pretty = pretty1 + pretty2 + pretty3

        pretty.unshift Col[Output.relative_path(file)].y

        pretty.join("\n")
      end
    end  # extract_code
    private :extract_code

  end  # module Output



  # --------------------------------------------------------------section---- #
  #                                                                           #
  #                        Output::BacktraceProcessor                         #
  #                                                                           #
  # ------------------------------------------------------------------------- #

  class Output
    class BacktraceProcessor
      INTERNALS_RE = (
        libdir = File.dirname(__FILE__)
        bindir = "bin/whitestone"
        Regexp.union(libdir, bindir)
      )

      def initialize(backtrace, filter_yn)
        @backtrace = filter(backtrace, filter_yn)
      end

      # +calls+ is an array of proc objects (scopes of the tests run so far,
      # from top level to current nesting).  The last of them is the context for
      # the current test, like
      #
      #   #<Proc:0x10b7b1b8@./test/shape/triangle/construct/various.rb:52>
      #
      # From this, we determine the current test file.  _Then_ we look in the
      # backtrace for the last mention of that test file.  That stack frame,
      # from the backtrace, tells us what line of code in the test file caused
      # the failure/error.
      #
      # If _calls_ is not provided, we simply take the first frame of the
      # backtrace.  That will happen when reporting a _failure_.  A failure is
      # simply a false assertion, so no stack unwinding is necessary.
      #
      # If no appropriate frame is found (not sure why that would be), then the
      # return values will be nil.
      #
      # Return:: file (String) and line number (Integer)
      def determine_file_and_lineno(calls=nil)
        frame =
          if calls
            current_test_file = calls.last.to_s.scan(/@(.+?):/).flatten.first
            @backtrace.find { |str| str.index(current_test_file) }
          else
            @backtrace.first
          end
        file, line =
          if frame
            file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
            [file, line.to_i]
          end
      end

      # Returns the backtrace (array of strings) with all paths converted to
      # relative paths (where possible).
      def backtrace
        make_relative(@backtrace)
      end

      def filter(backtrace, filter_yn)
        # TODO: remove (or update and move) following comment.
        #
        # It's up to the user whether we filter backtraces.  That's set in
        # @filter_backtrace_yn.  However, there are times when it makes sense to
        # _force_ a filter (if an AssertionSpecificationError is raised).  That's
        # what the parameter force_filter is for; it can override
        # @filter_backtrace_yn.
        if filter_yn
          backtrace.reject { |str| str =~ INTERNALS_RE }.uniq
        else
          backtrace.dup
        end
      end
      private :filter

      # Turn absolute paths into relative paths if possible, to save space and
      # ease reading.
      def make_relative(backtrace)
        backtrace.map { |path| Output.relative_path(path) }
      end
      private :make_relative

    end  # class BacktraceProcessor
  end  # module Output
end  # module Whitestone

