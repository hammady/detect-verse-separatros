#!/usr/bin/env ruby
require 'RMagick'
require 'phashion'
require 'ruby-progressbar'

# CHECK ARGUMENTS

usage = "USAGE: #{__FILE__} <input-image-file> <separator-image-file> [<border-width>]\n"
usage << "If <border-width> is not specified, 0 is assumed.\n"
usage << "On success, the script will output coordinates of each verse in sequential order"

if ARGV.length < 1 || ARGV.length > 3
  $stderr.puts usage
  exit 1
end

infile = ARGV[0]
separator_filename = ARGV[1]
border = ARGV[2].to_i

unless File.exists?(infile)
  $stderr.puts "File not found: #{infile}"
  $stderr.puts usage
  exit 2
end

unless File.exists?(separator_filename)
  $stderr.puts "File not found: #{separator_filename}"
  $stderr.puts usage
  exit 3
end

# PROCESS INPUT

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
  img.write("#{infile}.noborder.#{ext}")
end

# read separator file
separator = Magick::Image::read(separator_filename).first
separator_ph = Phashion::Image.new(separator_filename)

skip_y = (separator.rows * 1.0).round

# search for verse separator

matches = []

Dir.mkdir("tmp") unless Dir.exists?("tmp")
canvas = Magick::Draw.new
y = 0
pbar = ProgressBar.create(title: "Scanning", total: img.rows - separator.rows)
while y < img.rows - separator.rows
  pbar.progress = y
  x = img.columns - separator.columns
  match_found_x = match_found_y = false # because matching is fuzzy, get only last match from a running sequence of matches
  while x >= 0 
    candidate = img.crop(x, y, separator.columns, separator.rows)
    candidate_filename = "tmp/candidate_#{'%05i' % y}_#{'%05i' % x}.#{ext}"
    candidate.write candidate_filename
    candidate_ph = Phashion::Image.new(candidate_filename)

    if candidate_ph.duplicate?(separator_ph)
      match_found_x = match_found_y = true
    else
      if match_found_x  # last iteration was a match?
        matches << [x+1, y]
        # overlay box
        canvas.fill('red').fill_opacity(0.3).rectangle(x+1, y, x+1+separator.columns, y+separator.rows)
      end
      # File.unlink(candidate_filename)
      match_found_x = false
    end
    File.unlink(candidate_filename)
    x -= 1
  end

  y += match_found_y ? skip_y : 1
end
pbar.finish
canvas.draw(img)
img.write("#{infile}.out.#{ext}")


Dir.rmdir("tmp") rescue "" # not empty
