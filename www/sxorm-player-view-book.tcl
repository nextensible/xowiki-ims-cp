set title [[$package_id folder_id] title]
set toc   [$page include [list BookOrganization -style scorm_navigation -open_page $name -expand_all 1 -decoration plain]]
set i     [$page set __last_includelet]

::template::head::add_javascript -order A -src "/resources/scorm/1.2/prototype.js"
::template::head::add_javascript -order B -src "/resources/scorm/1.2/scorm_api.js"

# TODO This is dirty
set iframesrc "[::xo::cc url]?template_file=/packages/xowiki-ims-cp/www/view-raw&[::xo::cc actual_query]"

# prevent recursive books
if {$i ne "" && ![$page exists __is_book_page]} {
  set p     [$i position]
  set count [$i count]

  if {$count > 0} {
    set book_relpos [format %.2f%% [expr {100.0 * $p / $count}]]
    if {$p>1}      {set book_prev_link [$package_id pretty_link [$i page_name [expr {$p - 1}]]]}
    if {$p<$count} {set book_next_link [$package_id pretty_link [$i page_name [expr {$p + 1}]]]}
    set page_title "<h2>[$i current] $title</h2>"
  } else {
    set book_relpos 0.0%
    set page_title "<h2>$title</h2>"    
  }
}
set header_stuff [::xo::Page header_stuff]
