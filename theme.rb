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
  end

  def clear
    @masks = @h.times.map{[]}
    @colors = @h.times.map{[]}
  end

  def show
    line_color = 28
    @lines.each_with_index do |line, y|
      colors[y].fill(line_color, 0, line.size)
    end

    output = +''
    @h.times do |y|
      color = nil
      output << "\e[48;5;#{16+36*5+6*5+4}m"
      line = @lines[y]
      @w.times do |x|
        m = @masks[y][x] || 0
        c = @colors[y][x]
        if color != c
          output << "\e[38;5;#{color = c}m"
        end
        output << (line&.[](x) || CHARS[m])
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
params = 5.times.map do
  bi = rand(0.02..0.05)
  bo = rand(0.05..0.1)
  bm = bo * rand(1.0..2.0)
  {
    cx: rand(100),
    cy: rand(50),
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
    canvas.draw(cx, cy, radius+0.5, color){|x,y|
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
