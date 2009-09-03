::template::head::add_css -href "/resources/yui/2.7.0b/build/grids/grids-min.css"
::template::head::add_javascript -order A  -src  "/resources/scorm/1.2/prototype.js"
::template::head::add_javascript -order B  -src  "/resources/scorm/1.2/scorm_api.js"

::xowiki::ims::cp::Package initialize -url [ad_conn url]

set org_id [::xo::cc query_parameter organization_id]

set critem [$package_id get_page_from_name -name "file:imsmanifest.xml"]

if {$critem eq ""} {
    set organization "No manifest found"
} else {
    set m [$package_id get_manifest]
    if {$org_id eq ""} {
        set org [$m get_default_or_implicit_organization]
    } else {
        set org [$m get_organization -identifier $org_id]
    }
    set organization_selector [[${m}::organizations] asXHTML]
    set organization [$org asXHTML]
}
