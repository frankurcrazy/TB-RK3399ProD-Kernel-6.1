#include <linux/gpio.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/notifier.h>
#include <linux/of.h>
#include <linux/of_gpio.h>
#include <linux/platform_device.h>
#include <linux/reboot.h>
#include <linux/slab.h>

#define GPIO_LOW 0
#define GPIO_HIGH 1

static const struct of_device_id of_uhrst_match[] = {
	{ .compatible = "usbhub-reset", },
	{},
};
MODULE_DEVICE_TABLE(of, of_uhrst_match);

struct uhrst_drvdata {
	struct notifier_block reboot_notifier;
	int uhrst_gpio;
};

static int reboot_notifier_handler(struct notifier_block *nb,
					 unsigned long action, void *cmd)
{
	struct uhrst_drvdata *ddata;

	ddata = container_of(nb, struct uhrst_drvdata, reboot_notifier);
	gpio_set_value(ddata->uhrst_gpio, GPIO_LOW);

	return NOTIFY_DONE;
}

static int uhrst_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *node = dev->of_node;
	struct uhrst_drvdata *ddata;
	enum of_gpio_flags flag;
	int ret;
	int uhrst_gpio;

	ddata = devm_kzalloc(dev, sizeof(*ddata), GFP_KERNEL);
	if (!ddata)
		return -ENOMEM;

	uhrst_gpio = of_get_named_gpio_flags(node, "uhrst-gpio", 0, &flag);
	if (uhrst_gpio < 0) {
		dev_err(dev, "failed to read uhrst-gpio: %d\n", uhrst_gpio);
		return uhrst_gpio;
	}

	ret = devm_gpio_request(dev, uhrst_gpio, "usbhub-reset");
	if (ret) {
		dev_err(dev, "request gpio %d failed: %d\n", uhrst_gpio, ret);
		return ret;
	}

	ret = gpio_direction_output(uhrst_gpio, GPIO_HIGH);
	if (ret) {
		dev_err(dev, "failed to drive gpio %d high: %d\n", uhrst_gpio, ret);
		return ret;
	}

	gpio_export(uhrst_gpio, true);

	ddata->uhrst_gpio = uhrst_gpio;
	ddata->reboot_notifier.notifier_call = reboot_notifier_handler;
	ret = register_reboot_notifier(&ddata->reboot_notifier);
	if (ret) {
		dev_err(dev, "failed to register reboot notifier: %d\n", ret);
		return ret;
	}

	platform_set_drvdata(pdev, ddata);
	return 0;
}

static int uhrst_remove(struct platform_device *pdev)
{
	struct uhrst_drvdata *ddata = platform_get_drvdata(pdev);

	if (ddata)
		unregister_reboot_notifier(&ddata->reboot_notifier);

	return 0;
}

static void uhrst_shutdown(struct platform_device *pdev)
{
	struct uhrst_drvdata *ddata = platform_get_drvdata(pdev);

	if (ddata)
		gpio_set_value(ddata->uhrst_gpio, GPIO_LOW);
}

static struct platform_driver uhrst_driver = {
	.probe = uhrst_probe,
	.remove = uhrst_remove,
	.shutdown = uhrst_shutdown,
	.driver = {
		.name = "usbhub-reset",
		.of_match_table = of_uhrst_match,
	},
};

static int __init uhrst_modinit(void)
{
	return platform_driver_register(&uhrst_driver);
}
late_initcall(uhrst_modinit);

static void __exit uhrst_exit(void)
{
	platform_driver_unregister(&uhrst_driver);
}
module_exit(uhrst_exit);

MODULE_DESCRIPTION("USB Hub Reset Driver");
MODULE_LICENSE("GPL");