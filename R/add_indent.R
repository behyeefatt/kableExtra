#' Add indentations to row headers
#'
#' @param kable_input Output of `knitr::kable()` with `format` specified
#' @param positions A vector of numeric row numbers for the rows that need to
#' be indented.
#' @param level_of_indent a numeric value for the indent level. Default is 1.
#'
#' @examples x <- knitr::kable(head(mtcars), "html")
#' # Add indentations to the 2nd & 4th row
#' add_indent(x, c(2, 4), level_of_indent = 1)
#'
#' @export
add_indent <- function(kable_input, positions,
                       level_of_indent = 1, all_cols = FALSE) {

  if (!is.numeric(positions)) {
    stop("Positions can only take numeric row numbers (excluding header rows).")
  }
  kable_format <- attr(kable_input, "format")
  if (!kable_format %in% c("html", "latex")) {
    warning("Please specify format in kable. kableExtra can customize either ",
            "HTML or LaTeX outputs. See https://haozhu233.github.io/kableExtra/ ",
            "for details.")
    return(kable_input)
  }
  if (kable_format == "html") {
    return(add_indent_html(kable_input, positions, level_of_indent, all_cols))
  }
  if (kable_format == "latex") {
    return(add_indent_latex(kable_input, positions, level_of_indent, all_cols))
  }
}

# Add indentation for LaTeX
add_indent_latex <- function(kable_input, positions,
                             level_of_indent = 1, all_cols = FALSE) {
  table_info <- magic_mirror(kable_input)
  out <- solve_enc(kable_input)
  level_of_indent<-as.numeric(level_of_indent)

  if (table_info$duplicated_rows) {
    dup_fx_out <- fix_duplicated_rows_latex(out, table_info)
    out <- dup_fx_out[[1]]
    table_info <- dup_fx_out[[2]]
  }

  max_position <- table_info$nrow - table_info$position_offset

  if (max(positions) > max_position) {
    stop("There aren't that many rows in the table. Check positions in ",
         "add_indent_latex.")
  }

  for (i in positions + table_info$position_offset) {
    rowtext <- table_info$contents[i]
    if (all_cols) {
      new_rowtext <- latex_row_cells(rowtext)
      new_rowtext <- lapply(new_rowtext, function(x) {
        paste0("\\\\hspace\\{", level_of_indent ,"em\\}", x)
      })
      new_rowtext <- paste(unlist(new_rowtext), collapse = " & ")
    } else {
      new_rowtext <- latex_indent_unit(rowtext, level_of_indent)
    }
    out <- sub(paste0(rowtext, "\\\\\\\\"),
               paste0(new_rowtext, "\\\\\\\\"),
               out, perl = TRUE)
    table_info$contents[i] <- new_rowtext
  }
  out <- structure(out, format = "latex", class = "knitr_kable")
  attr(out, "kable_meta") <- table_info
  return(out)


}

latex_indent_unit <- function(rowtext, level_of_indent) {
  paste0("\\\\hspace\\{", level_of_indent ,"em\\}", rowtext)
}



# Add indentation for HTML
add_indent_html <- function(kable_input, positions,
                            level_of_indent = 1, all_cols = FALSE) {
  kable_attrs <- attributes(kable_input)

  kable_xml <- kable_as_xml(kable_input)
  kable_tbody <- xml_tpart(kable_xml, "tbody")

  group_header_rows <- attr(kable_input, "group_header_rows")
  if (!is.null(group_header_rows)) {
    positions <- positions_corrector(positions, group_header_rows,
                                     length(xml_children(kable_tbody)))
  }

  for (i in positions) {
    row_to_edit = xml_children(kable_tbody)[[i]]
    if (all_cols) {
      target_cols = 1:xml2::xml_length(row_to_edit)
    } else {
      target_cols = 1
    }

    for (j in target_cols) {
      node_to_edit <- xml_child(row_to_edit, j)
      if (!xml_has_attr(node_to_edit, "indentlevel")) {
        xml_attr(node_to_edit, "style") <- paste(
          xml_attr(node_to_edit, "style"), "padding-left: ",paste0(level_of_indent*2,"em;")
        )
        xml_attr(node_to_edit, "indentlevel") <- 1
      } else {
        indentLevel <- as.numeric(xml_attr(node_to_edit, "indentlevel"))
        xml_attr(node_to_edit, "style") <- sub(
          paste0("padding-left: ", indentLevel * 2, "em;"),
          paste0("padding-left: ", (indentLevel + 1) * 2, "em;"),
          xml_attr(node_to_edit, "style")
        )
        xml_attr(node_to_edit, "indentlevel") <- indentLevel + 1
      }
    }
  }
  out <- as_kable_xml(kable_xml)
  attributes(out) <- kable_attrs
  if (!"kableExtra" %in% class(out)) class(out) <- c("kableExtra", class(out))
  return(out)
}
