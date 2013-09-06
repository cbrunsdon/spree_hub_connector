Augury.Views.Home.AddIntegration = Backbone.View.extend(
  initialize: (attrs) ->
    @options = attrs
    @model = attrs.integration
    @enabledMappings = []
    @keyValueTemplate = JST['admin/templates/parameters/key_value_fields']
    @listTemplate = JST['admin/templates/parameters/list_fields']

    _.bindAll @, 'render'
    @listenTo Augury.integrations, 'reset', @render

  events:
    'click button#cancel': 'cancel'
    'click button#save': 'save'

  render: ->
    @options.parametersByConsumer = @parametersByConsumer()
    # Show modal
    @$el.html JST["admin/templates/home/edit_integration"](options: @options)

    # Setup modal tabs
    @$el.find("#modal-tabs").tabs().addClass("ui-tabs-vertical ui-helper-clearfix")
    @$el.find("#modal-tabs li").removeClass("ui-corner-top").addClass("ui-corner-left")

    # All inputs are disabled by default
    @$el.find('input').attr('disabled', true)

    # Copy text across duplicate inputs across consumers
    @$el.find('input').bind "keyup paste", ->
      current = $(@)
      duplicates = $("[name='#{current.attr('name')}']")
      if duplicates.length > 1
        duplicates.val(current.val())

    # Prepare consumer state toggle
    @$el.find('.integration-toggle').toggles({
      text: {
        on: 'Enabled',
        off: 'Disabled'
      },
      on: false,
      width: 90
    })

    # Show loading message while waiting for consumers to be present
    unless @model.get('consumers') && @model.get('consumers').length > 0
      @$el.html '<p>Please wait while we fetch the endpoint configuration...</p>'
    else
      @stopListening(Augury.integrations)


    @prepareClickHandlers()
    @validateListValues()
    @setActiveMappings()

    @

  setActiveMappings: ->
    for consumerName, parameters of @options.parametersByConsumer
      consumer = _(@options.integration.get('consumers')).findWhere(name: consumerName)
      if mapping = Augury.mappings.findWhere(name: "#{@options.integration.get('name')}.#{consumerName}")
        if mapping.get('enabled') == true
          @$el.find("*[data-consumer-name=#{consumerName}]").trigger('click')
        else
          @$el.find("*[data-consumer-name=#{consumerName}]").closest("#tabs-#{consumerName}").addClass('disabled')
      else
        @$el.find("*[data-consumer-name=#{consumerName}]").closest("#tabs-#{consumerName}").addClass('disabled')

  prepareClickHandlers: ->
    # Handle clicking on consumer toggle
    @$el.find('.integration-toggle').on 'toggle', (e, active) =>
      target = $(e.currentTarget)
      consumerName = target.data('consumer-name')
      mappingContainer = target.closest("#tabs-#{consumerName}")
      if active
        @enabledMappings.push consumerName
        target.closest('.row').find('input').attr('disabled', false)
        mappingContainer.removeClass('disabled')
      else
        index = @enabledMappings.indexOf consumerName
        if index != -1
          @enabledMappings.splice(index, 1)
          target.closest('.row').find('input').attr('disabled', true)
          mappingContainer.addClass('disabled')

    @$el.on 'click', '.add-new-row', (e) =>
      $(@keyValueTemplate()).insertBefore($(e.currentTarget).closest('.list-item').find('.list-row:last'))
      false

    @$el.on 'click', '.remove-row', (e) =>
      listItem = $(e.currentTarget).closest('.list-item')
      $(e.currentTarget).closest('.list-row').remove()
      if listItem.find('.list-row').length == 0
        listItem.remove()
      false

    @$el.on 'click', '.add-new-value', (e) =>
      # Add new value at the beginning of form
      $(e.currentTarget).closest('legend').after(@listTemplate())
      false

    # Show a confirmation modal when deleting a list value
    @$el.on 'click', '.delete-value', (e) ->
      e.preventDefault()
      listItem = $(e.currentTarget).closest('.list-item')
      $('#dialog-confirm').dialog
        dialogClass: 'dialog-delete'
        modal: true
        resizable: false
        draggable: false
        minHeight: 180
        buttons:
          "Yes": ->
            listItem.remove()
            $(@).dialog 'close'
          "No": ->
            $(@).dialog 'close'
      false

  parametersByConsumer: ->
    @ret = {}

    _.map(@model.get("consumers"), (consumer) =>
      @ret[consumer["name"]] = consumer["requires"]["parameters"]
    )
    @ret

  validateListValues: ->
    @$el.on 'change', '.list-item input', (e) ->
      e.preventDefault()
      inputs = $(@).closest('.list-item').find 'input.list-key'
      input_values = _(inputs).map (input) ->
        $(input).val()
      unique_input_values = _.uniq input_values
      if unique_input_values.length != input_values.length
        $('button#save')[0].disabled = true
        $(@).closest('.list-item').find('.key-error').remove()
        $(@).closest('.list-item').find('.actions').after('<p class="key-error">Names must be unique</p>')
      else
        $('button#save')[0].disabled = false
        $(@).closest('.list-item').find('.key-error').remove()

  buildValues: (e) ->
    _($('fieldset.list-value')).each (fieldset) =>
      if $(fieldset).find('.list-item').length > 0
        finalValue = []
        paramName = $(fieldset).data('parameter-name')
        _($(fieldset).find('.list-item')).each (value) =>
          currentValue = new Object()
          _($(value).find('.list-row')).each (element) ->
            key = $(element).find('input[name=key]:enabled').val()
            value = $(element).find('input[name=value]:enabled').val()
            if key && value
              currentValue[key] = value
          finalValue.push currentValue
        finalValueJSON = JSON.stringify(finalValue)
        @$el.append("<input class='parameter_value' name='#{paramName}' type='hidden' value='#{finalValueJSON}' />")

  validateForm: ->
    inputs = @$el.find('input:enabled')
    invalidInputs = _(inputs).filter (input) =>
      $(input).val() == ''

    if invalidInputs.length > 0
      _(invalidInputs).each (input) =>
        $(input).addClass('parsley-error')
        $(input).next('ul.parsley-error-list').remove()
        $(input).after('<ul class="parsley-error-list"><li class="parsley-error">Field is required</li></ul>')

        @$el.on 'keyup', 'input.parsley-error', (e) ->
          input = $(e.currentTarget)
          if input.val() != ''
            input.next('ul.parsley-error-list').fadeOut()
          else
            input.next('ul.parsley-error-list').fadeIn()

      return false
    else
      return true

  save: (e) ->
    e.preventDefault()
    if @validateForm()
      @buildValues()

      parameters = {}
      _(@$el.find('input.param:enabled')).each (param) ->
        param = $(param)
        val = param.val()
        if val?
          parameters[param.attr('name')] = val
        else
          console.log('missing')

      if @$el.find('input.parameter_value').length > 0
        _(@$el.find('input.parameter_value')).each (param) ->
          param = $(param)
          val = param.val()
          if val?
            parameters[param.attr('name')] = val
          else
            console.log 'missing'


      @model.signup(parameters, @enabledMappings)
        .done((mappings, textStatus, jqXHR) ->
          Augury.Flash.success 'The integration has been successfully updated.'
          Augury.parameters.fetch()

          _(mappings).each (mapping) ->
            existing = Augury.mappings.findWhere(name: mapping['name'])
            if existing?
              Augury.mappings.remove existing
            Augury.mappings.add new Augury.Models.Mapping(mapping)
          Augury.mappings.fetch
            success: ->
              Augury.integrations.fetch reset: true
          $('.ui-dialog-content').dialog('close')
        ).fail((jqXHR, textStatus, errorThrown, options) =>
          @displayErrors(null, jqXHR, options)
        )
    else
      @$el.find('.parsley-error:first').focus()

  cancel: (event) ->
    event.preventDefault()

    $('.ui-dialog-content').dialog 'close'
)
