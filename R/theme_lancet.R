# Shared figure style for the Malta HIA paper, Lancet Planetary Health look
# (analysis/instructions/Figure_ins.md, 2026-11-02). Typography, axes and export only:
# data, colours, scales, breaks and panel order stay with each figure.
#
# Font: Source Sans 3 (humanist sans close to the Lancet house font), installed per user in
# ~/.local/share/fonts/SourceSans3 (Adobe release 3.052R); fallback Arial, then Liberation Sans.
# Sizes in pt at final print size: ticks, legend text and annotations 7, axis and legend titles
# 8.5, panel letters and titles bold 9; nothing below 6.

lancet_font <- local({
  have <- unique(systemfonts::system_fonts()$family)
  cand <- c("Source Sans 3", "Arial", "Liberation Sans")
  hit  <- cand[cand %in% have]
  if (length(hit) == 0) "sans" else hit[1]
})

LANCET_W1 <- 80   # one column, mm
LANCET_W2 <- 170  # two columns, mm

# geom_text / annotate size (mm) for a size in pt
pt_size <- function(pt) pt / ggplot2::.pt

theme_lancet <- function(base_size = 8, base_family = lancet_font) {
  ggplot2::theme_classic(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      text              = ggplot2::element_text(colour = "black"),
      axis.text         = ggplot2::element_text(size = 7, colour = "black"),
      axis.title        = ggplot2::element_text(size = 8.5),
      axis.line         = ggplot2::element_line(linewidth = 0.25, colour = "black"),
      axis.ticks        = ggplot2::element_line(linewidth = 0.25, colour = "black"),
      legend.text       = ggplot2::element_text(size = 7),
      legend.title      = ggplot2::element_text(size = 8),
      legend.background = ggplot2::element_blank(),
      legend.key        = ggplot2::element_blank(),
      panel.grid        = ggplot2::element_blank(),
      strip.background  = ggplot2::element_blank(),
      strip.text        = ggplot2::element_text(face = "bold", size = 9, hjust = 0,
                                                margin = ggplot2::margin(b = 3)),
      plot.title        = ggplot2::element_blank(),
      plot.subtitle     = ggplot2::element_text(size = 7, hjust = 0, margin = ggplot2::margin(b = 3)),
      plot.caption      = ggplot2::element_text(size = 7, hjust = 0),
      # panel letter + short title as the tag ("A  Natural cause mortality"), top left
      plot.tag          = ggplot2::element_text(face = "bold", size = 9, hjust = 0, vjust = 0,
                                                margin = ggplot2::margin(b = 4)),
      plot.tag.position = c(0, 1),
      plot.tag.location = "plot",
      plot.margin       = ggplot2::margin(16, 4, 3, 3),
      plot.background   = ggplot2::element_rect(fill = "white", colour = NA))
}

# Maps: no axes, same type
theme_lancet_map <- function(base_size = 8, base_family = lancet_font) {
  theme_lancet(base_size, base_family) +
    ggplot2::theme(axis.line = ggplot2::element_blank(), axis.ticks = ggplot2::element_blank(),
                   axis.text = ggplot2::element_blank(), axis.title = ggplot2::element_blank())
}

# Small scale bar and north arrow in the figure font
lancet_scale_bar <- function(location = "bl", ...) {
  ggspatial::annotation_scale(location = location, width_hint = 0.2, text_cex = 7 / 12,
                              text_family = lancet_font, height = grid::unit(0.1, "cm"),
                              line_width = 0.3, bar_cols = c("grey20", "white"), ...)
}
lancet_north_arrow <- function(location = "tr", ...) {
  ggspatial::annotation_north_arrow(
    location = location, which_north = "true",
    height = grid::unit(0.55, "cm"), width = grid::unit(0.4, "cm"),
    style = ggspatial::north_arrow_orienteering(text_size = 6, text_family = lancet_font,
                                                line_width = 0.5), ...)
}

# Output folder: output/paper/figures_lancet/ for the main analysis, a subfolder per exposure
# otherwise, so sensitivity runs never overwrite the paper figures.
lancet_dir <- function(ndvi_exposure, out_dir) {
  d <- if (identical(ndvi_exposure, "s2median_buf300")) {
    file.path(dirname(out_dir), "figures_lancet")
  } else {
    file.path(out_dir, "figures_lancet")
  }
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  d
}

# Vector PDF with embedded editable text (cairo), SVG with text as text, PNG 300 dpi (ragg)
save_figure_lancet <- function(p, name, dir, height_mm, width_mm = LANCET_W2) {
  f <- file.path(dir, paste0(name, c(".pdf", ".svg", ".png")))
  ggplot2::ggsave(f[1], p, width = width_mm, height = height_mm, units = "mm",
                  device = grDevices::cairo_pdf, bg = "white")
  ggplot2::ggsave(f[2], p, width = width_mm, height = height_mm, units = "mm",
                  device = svglite::svglite, bg = "white", fix_text_size = FALSE)
  ggplot2::ggsave(f[3], p, width = width_mm, height = height_mm, units = "mm",
                  device = ragg::agg_png, res = 300, bg = "white")
  f
}

# Editable PowerPoint version (DrawingML via rvg: every line, point and label stays an
# editable shape), one slide at the figure's final size. Text keeps the figure font name;
# PowerPoint substitutes a similar font where Source Sans 3 is not installed.
save_figure_pptx <- function(p, name, dir, height_mm, width_mm = LANCET_W2) {
  f <- file.path(dir, paste0(name, ".pptx"))
  doc <- officer::read_pptx()
  doc <- officer::add_slide(doc, layout = "Blank", master = "Office Theme")
  doc <- officer::ph_with(doc, rvg::dml(ggobj = p, bg = "white"),
                          location = officer::ph_location(left = 0.3, top = 0.3,
                                                          width = width_mm / 25.4,
                                                          height = height_mm / 25.4))
  print(doc, target = f)
  f
}
