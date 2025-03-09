require 'reline'
module IRB2025Mikan
  class Canvas
    CHARS = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'
    attr_reader :w, :h, :masks, :colors
    attr_accessor :lines, :focus_line
    def initialize(w, h)
      @w = w
      @h = h
      clear
      # TODO: delete this
      @lines = (@h/2).times.map do
        rand(2..40).times.map{rand(33..126).chr}.join
      end
      @focus_line = rand(@lines.size)
    end

    def clear
      @masks = @h.times.map{[]}
      @colors = @h.times.map{[]}
    end

    def render_to_lines
      output_lines = []
      @h.times do |y|
        color = nil
        default_background = 16+36*5+6*5+4
        text_color = 16+36*0+6*2+0
        line = @lines[y]
        if y == @focus_line
          default_background = 16+36*5+6*5+3
          line = line.sub('  ', '🍊')
          text_color = "#{16+36*0+6*1+0};1"
        end 
        output = +''
        background = color = nil
        x = 0
        chars = line ? line.grapheme_clusters.flat_map { |c|
          case Reline::Unicode.get_mbchar_width(c)
          when 2
            [[c, 2], :skip]
          when 1
            [[c, 1]]
          else
            []
          end
        } : []
        while x < @w do
          m = @masks[y][x] || 0
          c, cw = chars[x]
          if c == :skip
            x += 1
            next
          end
          c = nil if c == ' '

          col = @colors[y][x]
          bg = default_background
          if c && x + cw <= @w
            bg = m == 0 ? default_background : col || default_background
            col = text_color
            x += cw
          else
            x += 1
          end
          if color != col
            output << "\e[38;5;#{color = col}m"
          end
          if background != bg
            output << "\e[48;5;#{background = bg}m"
          end
          output << (c || CHARS[m])
        end
        output << "\e[m"
        output_lines << output
      end
      output_lines
    end

    def draw(cx, cy, r, color)
      offset = 2
      plot = ->x, y, v, color {
        val = @masks[y/2][x/2] || 0
        bit = 1 << (y % 2 * 2 + x % 2)
        @masks[y/2][x/2] = (val & ~bit) | (v * bit)
        @colors[y/2][x/2] = color if color
      }
      xrange = ([2 * (cx - r - offset), 0].max.ceil..[2 * (cx + r + offset), 2 * @w - 1].min)
      yrange = ([2 * cy - r - offset, 0].max.ceil..[2 * cy + r + offset, 2 * @h - 1].min)
      yrange.each do |iy|
        xrange.each do |ix|
          x = ix - 2 * cx
          y = (iy - 2 * cy) * 2.0
          r2 = x ** 2 + y ** 2
          next if r2 > 4 * (r + offset)**2
          if r2 > 4 * (r + 0.5) ** 2
            plot[ix, iy, 0, nil]
          else
            plot[ix, iy, yield(x / 2.0 / r, y / 2.0 / r) ? 1 : 0, color]
          end
        end
      end
    end
  end

  def self.params
    prev_color = nil
    @params ||= 100.times.map do |i|
      bi = rand(0.02..0.05)
      bo = rand(0.05..0.1)
      bm = bo * rand(1.0..2.0)
      color = prev_color
      color = 16+36*5+6*rand(3..5)+rand(1..2) while color == prev_color
      prev_color = color
      {
        cx: rand,
        cy: 15 * i + rand(10),
        segments: rand(7..9),
        theta: 2 * Math::PI * rand,
        rot: (0.2 + 0.4 * rand) * (rand > 0.5 ? 1 : -1),
        bi:, bm:, bo:,
        radius: rand(12..24),
        color:
      }
    end
  end

  def self.reset_params
    @params = nil
  end

  def self.start
    Reline::LineEditor.prepend Module.new {
      def colorize_completion_dialog
        dialog = @dialogs[0]
        unless dialog&.contents
          IRB2025Mikan.reset_params
          return
        end

        canvas = Canvas.new(dialog.width, dialog.contents.size)
        face = Reline::Face[:completion_dialog]
        time = Time.now.to_f
        original_contents = dialog.contents.instance_eval { @original ||= dup }
        canvas.focus_line = original_contents.find_index { |line| line.include?(face[:enhanced]) }
        uncolored_lines = original_contents.map do |line|
          line.gsub(/\e\[[\d;]*m/, '')
        end
        canvas.lines = uncolored_lines
        IRB2025Mikan.params.each do |param|
          param in { cx:, cy:, segments:, theta:, rot:, bo:, bi:, bm:, radius:, color: }
          cy = (cy - dialog.scroll_top) % 1500 - 100
          theta += time * rot
          canvas.draw(5 + (canvas.w - 5)*cx, cy, radius+0.5, color){|x,y|
            z = x+y.i
            a = z.arg
            a2 = ((a-theta)/2/Math::PI*segments).round*2*Math::PI/segments+theta
            (z*Complex.polar(1, -a2)).imag.abs > bi + 10**(10*(z.abs2 - 1 + bo + bm)) || (z.abs<1&&z.abs>1-bo)
          }
        end

        dialog.contents[0..] = canvas.render_to_lines
      end

      def update_dialogs(...)
        @_updating_dialogs = true
        super(...)
        colorize_completion_dialog
      ensure
        @_updating_dialogs = false
      end

      def _updating_dialogs?
        @_updating_dialogs
      end

      def rerender
        (@mutex ||= Mutex.new).synchronize { super }
      end
    }
    Thread.new do
      Reline.line_editor.instance_eval do
        loop do
          sleep 0.1
          colorize_completion_dialog && rerender unless _updating_dialogs?
        end
      end
    end
  end
end

IRB2025Mikan.start
