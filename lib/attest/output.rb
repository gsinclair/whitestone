
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
    def filter_backtrace(b, smart=false)
      # If the first item in the backtrace is 'internal', then whatever error
      # occurred is an internal one and we need to see the guts of it.
      # This behaviour is only enabled if 'smart' is true.
      if smart and b.first =~ INTERNALS_RE
        b
      else
        b.reject { |str| str =~ INTERNALS_RE }.uniq
      end
    end
    private :filter_backtrace



    ##
    # Print the name and result of each test, using indentation.
    # This must be done after execution is finished in order to get the tree
    # structure right.
    def display_test_by_test_result(top_level)
      pipe = "|".cyan.bold
      space = " "
      empty_line = space + pipe + (space * 76) + pipe
      puts
      puts (" +----- Report " + "-" * (77-14) + "+").cyan.bold
      tree_walk(top_level.tests) do |test, level|
        string1 = (space + space + "  " * level + test.description).ljust(67)
        string1 = string1[0...67]
        string2 = "  " + test.result.to_s.upcase
        colour2 = case test.result
                  when :pass then :green
                  when :fail then :red
                  when :error then :magenta
                  end
        colour1 = (test.passed?) ? :uncolored : colour2
        style1  = (test.passed?) ? :uncolored : :bold
        if level == 0
          puts empty_line
          colour1 = (test.passed?) ? :yellow : colour2
          style1  = :bold
        end
        padding = space * ( 77 - (1 + (string1 + string2).size) )
        string1 = string1.send(colour1).send(style1)
        string2 = string2.send(colour2).bold
        puts space + pipe + string1 + string2 + padding + pipe
      end
      puts empty_line
      puts " +#{'-'*76}+".cyan.bold
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
      npass      = stats[:pass]  || 0
      nfail      = stats[:fail]  || 0
      nerror     = stats[:error] || 0
      overall    = (nfail + nerror > 0) ? :FAIL : :PASS
      time       = stats[:time]
      assertions = stats[:assertions]

      overall_colour    = (overall == :PASS)  ?  :green  :  :red
      npass_colour      = :green
      nfail_colour      = (nfail  > 0)  ?  :red      :  :green
      nerror_colour     = (nerror > 0)  ?  :magenta  :  :green
      time_colour       = :white
      assertions_colour = :white

      overall_str    = overall.to_s.ljust(9).send(overall_colour).bold
      npass_str      = (sprintf "#pass: %-6d",  npass).send(npass_colour).bold
      nfail_str      = (sprintf "#fail: %-6d",  nfail).send(nfail_colour).bold
      nerror_str     = (sprintf "#error: %-6d", nerror).send(nerror_colour).bold
      assertions_str = (sprintf "assertions: %-6d", assertions).send(assertions_colour)
      time_str       = (sprintf "time: %3.3f", time).send(time_colour)

      equals = ("=" * 80).send(overall_colour).bold
      nl = "\n"
      output = String.new.tap { |str|
        str << equals << nl
        str << " " << overall_str << npass_str      << nfail_str <<
                      nerror_str  << assertions_str << time_str  << nl
        str << equals << nl
      }

      puts
      puts output
    end



    def report_failure(description, message, backtrace)
      backtrace = filter_backtrace(backtrace, :smart)

      # Determine the file and line number of the failed assertion, and extract
      # the code surrounding that line.
      file, line =
        if frame = backtrace.first
          file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
          [file, line.to_i]
        end
      code =
        if file and line and file != "(eval)"
          extract_code(file, line)
        end

      # Emit the failure report.
      @buf.puts
      @buf.puts "FAIL: #{description}".red.bold
      @buf.puts code.___indent(4) if code
      message ||= "No message! #{__FILE__}:#{__LINE__}"
      @buf.puts message.___indent(2)
      @buf.puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
    end  # report_failure



    def report_uncaught_exception(description, exception, _calls)
      backtrace = filter_backtrace(exception.backtrace, :smart)

      # Determine the current test file, the line number that triggered the
      # error, and extract the code surrounding that line.
      current_test_file = _calls.last.to_s.scan(/@(.+?):/).flatten.first
      frame = backtrace.find { |str| str.index(current_test_file) }
      file, line =
        if frame
          file, line = frame.scan(/(.+?):(\d+(?=:|\z))/).first
          [file, line.to_i]
        end
      code =
        if file and line and file != "(eval)"
          extract_code(file, line)
        end

      # Emit the error report.
      @buf.puts
      @buf.puts "ERROR: #{description}".magenta.bold
      @buf.puts code.___indent(4) if code
      @buf.puts "  Class:   ".magenta.bold + exception.class.to_s.yellow.bold
      @buf.puts "  Message: ".magenta.bold + exception.message.yellow.bold
      @buf.puts "  Backtrace\n" + backtrace.join("\n").___indent(4)
    end  # report_uncaught_exception



    def report_specification_error(e)
      puts
      puts "You have made an error in specifying one of your assertions."
      puts "Details below; can't continue; exiting."
      puts
      puts "Message: #{e.message.yellow.bold}"
      puts
      puts "Filtered backtrace:"
      puts filter_backtrace(e.backtrace).join("\n").___indent(2)
      puts
      puts "Full backtrace:"
      puts e.backtrace.join("\n").___indent(2)
      puts
    end


    private

    def extract_code(file, line)
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
    end  # extract_code
    private :extract_code

  end  # module Output
end  # module Attest

