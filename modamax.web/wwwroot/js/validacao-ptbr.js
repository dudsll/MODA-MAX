// A aplicacao usa a cultura pt-BR (virgula decimal): o servidor entende "1.234,56".
// Por padrao o jQuery Validation so aceitaria "1234.56" e recusava os precos exibidos no proprio formulario.
(function ($) {
    if (!$ || !$.validator) return;

    var numeroPtBr = /^-?(?:\d{1,3}(?:\.\d{3})+|\d+)(?:,\d+)?$/;

    function paraNumero(valor) {
        return parseFloat(String(valor).replace(/\./g, '').replace(',', '.'));
    }

    $.validator.methods.number = function (valor, elemento) {
        return this.optional(elemento) || numeroPtBr.test(valor);
    };

    $.validator.methods.range = function (valor, elemento, limites) {
        return this.optional(elemento) || (paraNumero(valor) >= limites[0] && paraNumero(valor) <= limites[1]);
    };

    $.validator.methods.min = function (valor, elemento, minimo) {
        return this.optional(elemento) || paraNumero(valor) >= minimo;
    };

    $.validator.methods.max = function (valor, elemento, maximo) {
        return this.optional(elemento) || paraNumero(valor) <= maximo;
    };
})(window.jQuery);
