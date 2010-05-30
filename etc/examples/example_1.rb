
  # This example runs some tests against the Date class.  All of them pass.
  # The Date class is large and complex; this barely scratches the surface.

  require 'date'

  D "Date" do

    D.< {                                 # setup for each block
      @d = Date.new(1972, 5, 13)
    }

    D "#to_s" do
      Eq @d.to_s, "1972-05-13"
    end

    D "#next" do
      end_of_april = Date.new(2010, 4, 30)
      start_of_may = Date.new(2010, 5, 1)
      T { end_of_april.next == start_of_may }
    end

    D "day, month, year, week, day-of-year, etc." do

      D.< { :extra_setup_for_these_three_blocks_if_required }

      D "civil" do
        Eq @d.year,   1972
        Eq @d.month,  5
        Eq @d.day,    13
      end
      D "commercial" do
        Eq @d.cwyear, 1972
        Eq @d.cweek,  19       # Commercial week-of-year
        Eq @d.cwday,  6        # Commercial day-of-week (6 = Sat)
      end
      D "ordinal" do
        Eq @d.yday,   134      # 134th day of the year
      end
    end

    D "#leap?" do
      [1984, 2000, 2400].each do |year|
        T { Date.new(year, 6, 27).leap? }
      end
      [1900, 2007, 2100, 2401].each do |year|
        F { Date.new(year, 12, 3).leap? }
      end
    end

  end
