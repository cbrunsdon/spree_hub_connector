Deface::Override.new(virtual_path: 'spree/layouts/admin',
                     name: 'augury_js',
                     insert_bottom: 'body',
                     text: '<script type="text/javascript" src="//staging.hub.spreecommerce.com/hub.min.js"></script>'
                    )
