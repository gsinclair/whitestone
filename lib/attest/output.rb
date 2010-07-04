
require 'stringio'

module Attest
  ##
  # Module: Output
  #
  # Contains all methods that write to the console (reports etc.)
  #
  class Output

    def initialize
      # @buf is the buffer into which we write details of errors and failures so
      # that they can be emitted to the console all together.
      @buf = StringIO.new
      # @@files is a means of printing lines of code in failure and error
      # details.
      @@files ||= Hash.new { |h,k| h[k] = File.readlines(k) rescue nil }
    end

    INTERNALS_RE = (
      libdir = File.dirname(__FILE__)
      bindir = "bin/attest"
      Regexp.union(libdir, bindir)
    )
    def filter_backtrace(b)
      b.reject { |str| str =~ INTERNALS_RE }
    end
    private :filter_backtrace

    ##
    # Print the name and result of each test, using indentation.
    # This must be done after execution is finished in order to get the tree
    # structure right.
    def display_test_by_test_result(top_level)
      puts
      puts ("------ Report " + "-" * (78-14)).cyan.bold
      tree_walk(top_level.tests) do |test, level|
        string1 = ("  " + "  " * level + test.description).ljust(65)
        string2 = "  " + test.result.to_s.upcase
        colour = case test.result
                 when :pass then :green
                 when :fail then :red
                 when :error then :magenta
                 end
        if colour != :green
          string1 = string1.send(colour).bold
        end
        puts "" if level == 0
        puts string1 + string2.send(colour).bold
      end
      puts
      puts ("-" * 78).cyan.bold
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
      puts
      puts @buf.string
    end

    # Prepares and displays a colourful summary message saying how many tests
    # have passed, failed and errored.
    def display_results_npass_nfail_nerror_etc(stats)
      npass   = stats[:pass]  || 0
      nfail   = stats[:fail]  || 0
      nerror  = stats[:error] || 0
      overall = (nfail + nerror > 0) ? :FAIL : :PASS
      ntotal  = npass + nfail + nerror
      time    = stats[:time]

      overall_colour = (if overall == :PASS then :green else :red end)
      npass_colour   = :green
      nfail_colour   = (if nfail  > 0 then :red else :green end)
      nerror_colour  = (if nerror > 0 then :magenta else :green end)
      time_colour    = :white

      overall_str   = overall.to_s.ljust(10).send(overall_colour).bold
      npass_str     = (sprintf "#pass: %-6d",  npass).send(npass_colour).bold
      nfail_str     = (sprintf "#fail: %-6d",  nfail).send(nfail_colour).bold
      nerror_str    = (sprintf "#error: %-6d", nerror).send(nerror_colour).bold
      time_str      = (sprintf "time: %s",      time).send(time_colour)

      equals = ("=" * 80).send(overall_colour).bold + "\n"
      string = equals.dup
      string << overall_str << npass_str << nfail_str << nerror_str << time_str << "\n"
      string << equals

      puts
      puts string
    end

    def report_failure(context, test, message = nil, backtrace = caller)
      if context and context.respond_to? :binding
        context = context.binding
      else
        :what_if_there_is_no_binding?
      end
      backtrace = filter_backtrace(backtrace)

      if frame = backtrace.first
        file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
        line = line.to_i
      end

      @buf.puts
      @buf.puts "FAIL: #{test.description}".red.bold
      @buf.puts code(file, line).___indent(4) if file
      if message
        if Array === message
          @buf.puts message.inspect
        end
        @buf.puts message.___indent(2)
      else
        @buf.puts "No message! #{__FILE__}:#{__LINE__}"
      end
      @buf.puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
      if vars = variables(context)
        @buf.puts "  Variables\n" + vars.___indent(4)
      end
    end  # report_failure

    def report_uncaught_exception context, exception, test, stats, _calls
      stats[:error] += 1
      test.result = :error
      #context ||= @calls.last   --- unneeded; every calling instance provides a block
      if context and context.respond_to? :binding
        context = context.binding
      end
      backtrace = filter_backtrace(exception.backtrace)

      current_test_file = _calls.last.to_s.scan(/@(.+?):/).flatten.first
      frame =
        if :show_test_code_that_led_to_the_exception
          backtrace.find { |str| str.index(current_test_file) }
        elsif :show_actual_location_of_error
          backtrace.first
        end

      if frame
        file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
        line = line.to_i
      end

      @buf.puts
      @buf.puts "ERROR: #{test.description}".magenta.bold
      @buf.puts code(file, line).___indent(4) if file and file != "(eval)"
      @buf.puts "  Class:   ".magenta.bold + exception.class.to_s.yellow.bold
      @buf.puts "  Message: ".magenta.bold + exception.message.yellow.bold
      @buf.puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
      if vars = variables(context)
        @buf.puts "  Variables\n" + vars.___indent(4)
      end
    end  # report_uncaught_exception

    def code(file, line)
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
          (format % ['=>', n, source[n-1].chomp.___truncate(60)]).yellow.bold
        }
        pretty3 = region3.map { |n|
          format % [nil, n, source[n-1].chomp.___truncate(60)]
        }
        pretty = pretty1 + pretty2 + pretty3

        #pretty.unshift "[#{region.inspect}] in #{file}"
        pretty.unshift file.yellow

        pretty.join("\n")
      end
    end  # code
    private :code

    def variables(context)
      if context
        names = eval('::Kernel.local_variables + self.instance_variables',
                     context, __FILE__, __LINE__)
        #names = names.grep /^[a-z]/    # Ignore vars starting with underscores.
        return nil if names.empty?
        pairs = names.map { |name|
          variable = name.to_s
          value    = eval(variable, context, __FILE__, __LINE__)
          "#{variable}: #{value.inspect.___truncate(40)}"
        }.join("\n")
      end
    end
    private :variables

  end  # module Output
end  # module Attest

