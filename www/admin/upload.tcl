::xowiki::Package initialize -ad_doc {
} -parameter {
  {replace 0}
}


set msg ""
ad_form \
    -name upload_form \
    -mode edit \
    -html { enctype multipart/form-data } \
    -form {
      {upload_file:file(file) {html {size 30}} {label "Import file for upload"} }
      {empty_first:integer(radio),optional {options {{yes 1} {no 0}}} {value 1} 
        {label "Empty this instance first"}
        {help_text "This will delete all pages in this instance before importing the package"}
      }
      {replace:integer(radio),optional {options {{yes 1} {no 0}}} {value 0} 
        {label "Replace objects"}
        {help_text "If checked, import will delete the object if it exists and create it new, otherwise import just adds a revision"}
      }
      {ok_btn:text(submit) {label "[_ acs-templating.HTMLArea_SelectUploadBtn]"}
      }
    } \
    -on_submit {
      if {$upload_file eq ""} {
          template::form::set_error upload_form upload_file [_ acs-templating.HTMLArea_SpecifyUploadFilename] break 
      }
      # foreach o [::xowiki::Page allinstances] {
      #   set preexists($o) 1
      # }
        ::ims::cp::PackageInterchangeFile create pif -location [template::util::file::get_property tmp_filename $upload_file]

        set pkg [pif unpack]
        $pkg mixin add ::xowiki::ims::cp::ContentPackage
        $pkg set xo_pkg_obj $package_id
        $pkg empty_target_wiki
    } -after_submit {
        $pkg import_to_wiki_instance
        ad_returnredirect "list"
    }
set context .
