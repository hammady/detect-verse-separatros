#!/usr/bin/env ruby
require 'RMagick'
require 'phashion'

# CHECK ARGUMENTS

usage = "USAGE: #{__FILE__} <input-image-file> [<number-of-lines>] [<border-width>]\n"
usage << "If <number-of-lines> is not specified, 15 is assumed.\n"
usage << "If <border-width> is not specified, 0 is assumed.\n"
usage << "On success, the script will output coordinates of each verse in sequential order"

if ARGV.length < 1 || ARGV.length > 3
  $stderr.puts usage
  exit 1
end

infile = ARGV[0]
nlines = (ARGV[1] || 15).to_i
border = ARGV[2].to_i

unless File.exists?(infile)
  $stderr.puts "File not found: #{infile}"
  $stderr.puts usage
  exit 2
end

if nlines == 0 || nlines > 100
  $stderr.puts "<number-of-lines> should be from 1 to 100"
  $stderr.puts usage
  exit 3
end

# PROCESS INPUT

$stderr.puts "Now processing #{infile} having #{nlines} lines, please be patient..."

# load input-image-file

img = Magick::Image.read(infile).first
$stderr.puts "   Format: #{img.format}"
$stderr.puts "   Geometry: #{img.columns}x#{img.rows}"
$stderr.puts "   Depth: #{img.depth} bits-per-pixel"
$stderr.puts "   Colors: #{img.number_colors}"
$stderr.puts "   Resolution: #{img.x_resolution.to_i}x#{img.y_resolution.to_i} "+
    "pixels/#{img.units == Magick::PixelsPerInchResolution ?
    "inch" : "centimeter"}"

ext = img.format.downcase

if border > 0
  # remove border
  img.crop!(border, border, img.columns - 2 * border, img.rows - 2 * border, true)
  img.write("noborder.#{ext}")
end

line_height = img.rows/nlines

# if img.properties.length > 0
#     $stderr.puts "   Properties:"
#     img.properties { |name,value|
#         $stderr.puts %Q|      #{name} = "#{value}"|
#     }
# end

# TEMPORARY: GENERATE SEPARATOR BY SPLITTING INPUT IMAGE INTO LINES
1.upto(nlines) {|n|
  img.crop(0, line_height*(n-1), img.columns, line_height, true).write("line#{n}.#{ext}")
}

exit 0

# read separator file
separator_filename = File.expand_path("../separator2.#{ext}", __FILE__)
separator = Magick::Image::read(separator_filename).first
separator_ph = Phashion::Image.new(separator_filename)

# search for verse separator

Dir.mkdir("tmp") unless Dir.exists?("tmp")
canvas = Magick::Draw.new
# for each line
y = 0
nlines.times { |line|
  $stderr.puts "Line #{line+1}"
  # for each separator candidate
  x = img.columns - separator.columns
  match_found = false # because matching is fuzzy, get only last match from a running sequence of matches
  while x >= 0 
    candidate = img.crop(x, y, separator.columns, separator.rows)
    candidate_filename = "tmp/candidate_#{line}_#{'%03i' % x}.#{ext}"
    candidate.write candidate_filename
    candidate_ph = Phashion::Image.new(candidate_filename)

    # $stderr.puts candidate_ph.distance_from(separator_ph)
    # if candidate_ph.duplicate?(separator_ph, :threshold => 20)
    if candidate_ph.duplicate?(separator_ph)
      match_found = true
    else
      if match_found  # last iteration was a match?
        $stderr.puts "MATCH AT #{x+1}, #{y}"
        # overlay box
        canvas.fill('red').fill_opacity(0.3).rectangle(x+1, y, x+1+separator.columns, y+line_height)
      end
      File.unlink(candidate_filename)
      match_found = false
    end
    # File.unlink(candidate_filename)
    x -= 1
  end

  y += line_height  
}
canvas.draw(img)
img.write("img2.#{ext}")

Dir.rmdir("tmp") rescue "" # not empty
