CHARS = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'

def render(w, h)
  lines = (h*2).times.map do |y|
    (w*2).times.map do |x|
      yield((x+0.5)/w-1, (y+0.5)/h-1) ? 1 : 0
    end
  end.each_slice(2).map do |a, b|
    a.each_slice(2).zip(b.each_slice(2)).map do |(a0,a1),(b0,b1)|
      CHARS[b1*8+b0*4+a1*2+a0]
    end.join
  end
  puts lines
end

100.times do
  n = rand(7..9)
  theta_offset = 2 * Math::PI * rand
  bo = rand(0.05..0.1)
  bi = rand(0.02..0.05)
  bm = bo * rand(1..2)
  radius = rand(8..12)
  $><<"\e[48;5;#{16+36*5+6*5+4}m"
  $><<"\e[38;5;#{16+36*5+6*rand(3..5)+rand(1..2)}m"
  10.times{
    theta_offset+=0.05
    $><<"\e[H"
    render(4*radius,2*radius){|x,y|
      z = x+y.i
      a = z.arg
      a2 = ((a-theta_offset)/2/Math::PI*n).round*2*Math::PI/n+theta_offset
      (z*Complex.polar(1, -a2)).imag.abs > bi + 10**(10*(z.abs2 - 1 + bo + bm)) || (z.abs<1&&z.abs>1-bo)  
    }
    sleep 0.1
  }
  $><<"\e[m"
  $><<"\e[H\e[J"
end