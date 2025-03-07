class Canvas
  CHARS = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'
  attr_reader :w, :h, :masks, :colors
  attr_accessor :lines
  def initialize(w, h)
    @w = w
    @h = h
    clear
    @lines = (@h/2).times.map do
      rand(2..40).times.map{rand(33..126).chr}.join
    end
    @focus_line = rand(@lines.size)
  end

  def clear
    @masks = @h.times.map{[]}
    @colors = @h.times.map{[]}
  end

  def show
    output = +''
    @h.times do |y|
      color = nil
      default_background = 16+36*5+6*5+4
      text_color = 16+36*0+6*2+0
      line = @lines[y]
      if y == @focus_line
        default_background = 16+36*5+6*4+2
        line = "#{line}🍊"
        text_color = "#{16+36*0+6*1+0};1"
      end
      background = default_background
      output << "\e[48;5;#{background}m"
      x = 0
      while x < @w do
        m = @masks[y][x] || 0
        t = line&.[](x)
        tlen = t.ascii_only? ? 1 : 2 if t
        c = @colors[y][x]
        bg = default_background
        if t && x + tlen <= @w
          bg = m == 0 ? default_background : c || default_background
          c = text_color
          x += tlen
        else
          x += 1
        end
        if color != c
          output << "\e[38;5;#{color = c}m"
        end
        if background != bg
          output << "\e[48;5;#{background = bg}m"
        end
        output << (t || CHARS[m])
      end
      output << "\e[m\n"
    end
    puts output
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

canvas = Canvas.new(100, 50)
params = 100.times.map do |i|
  bi = rand(0.02..0.05)
  bo = rand(0.05..0.1)
  bm = bo * rand(1.0..2.0)
  {
    cx: rand,
    cy: 15 * i + rand(10),
    segments: rand(7..9),
    theta: 2 * Math::PI * rand,
    rot: (0.02 + 0.04 * rand) * (rand > 0.5 ? 1 : -1),
    bi:, bm:, bo:,
    radius: rand(12..20),
    color: 16+36*5+6*rand(3..5)+rand(1..2)
  }
end

(0..).each do |t|
  canvas.clear
  params.each do |param|
    param in { cx:, cy:, segments:, theta:, rot:, bo:, bi:, bm:, radius:, color: }
    theta += t * rot
    canvas.draw(canvas.w*(1+cx)/2.0, cy, radius+0.5, color){|x,y|
      z = x+y.i
      a = z.arg
      a2 = ((a-theta)/2/Math::PI*segments).round*2*Math::PI/segments+theta
      (z*Complex.polar(1, -a2)).imag.abs > bi + 10**(10*(z.abs2 - 1 + bo + bm)) || (z.abs<1&&z.abs>1-bo)
    }
  end
  $><<"\e[H"
  canvas.show
  sleep 0.1
end
