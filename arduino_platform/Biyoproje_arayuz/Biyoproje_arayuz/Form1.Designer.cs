namespace Biyoproje_arayuz
{
    partial class Form1
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            this.rightbutton = new System.Windows.Forms.Button();
            this.downbutton = new System.Windows.Forms.Button();
            this.leftbutton = new System.Windows.Forms.Button();
            this.upbutton = new System.Windows.Forms.Button();
            this.cambutton = new System.Windows.Forms.Button();
            this.oto = new System.Windows.Forms.Button();
            this.manuel = new System.Windows.Forms.Button();
            this.disttext = new System.Windows.Forms.TextBox();
            this.verticaltext = new System.Windows.Forms.TextBox();
            this.horizontaltext = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.label4 = new System.Windows.Forms.Label();
            this.manueldist = new System.Windows.Forms.TextBox();
            this.SerialPort = new System.IO.Ports.SerialPort(this.components);
            this.comboBox1 = new System.Windows.Forms.ComboBox();
            this.label5 = new System.Windows.Forms.Label();
            this.delaytext = new System.Windows.Forms.TextBox();
            this.label6 = new System.Windows.Forms.Label();
            this.label7 = new System.Windows.Forms.Label();
            this.repeatbox = new System.Windows.Forms.TextBox();
            this.label10 = new System.Windows.Forms.Label();
            this.speedbox = new System.Windows.Forms.TextBox();
            this.label11 = new System.Windows.Forms.Label();
            this.home_button = new System.Windows.Forms.Button();
            this.homing = new System.Windows.Forms.Label();
            this.button1 = new System.Windows.Forms.Button();
            this.button2 = new System.Windows.Forms.Button();
            this.label3 = new System.Windows.Forms.Label();
            this.label12 = new System.Windows.Forms.Label();
            this.label8 = new System.Windows.Forms.Label();
            this.label1 = new System.Windows.Forms.Label();
            this.timer1 = new System.Windows.Forms.Timer(this.components);
            this.label = new System.Windows.Forms.Label();
            this.camdelaybox = new System.Windows.Forms.TextBox();
            this.label9 = new System.Windows.Forms.Label();
            this.label13 = new System.Windows.Forms.Label();
            this.Switch_homing = new System.Windows.Forms.Button();
            this.label14 = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // rightbutton
            // 
            this.rightbutton.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.rightbutton.Cursor = System.Windows.Forms.Cursors.Hand;
            this.rightbutton.Font = new System.Drawing.Font("Times New Roman", 7.8F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.rightbutton.Location = new System.Drawing.Point(832, 414);
            this.rightbutton.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.rightbutton.Name = "rightbutton";
            this.rightbutton.Size = new System.Drawing.Size(88, 94);
            this.rightbutton.TabIndex = 0;
            this.rightbutton.Text = "RIGHT";
            this.rightbutton.UseVisualStyleBackColor = false;
            this.rightbutton.Click += new System.EventHandler(this.rightbutton_Click);
            // 
            // downbutton
            // 
            this.downbutton.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.downbutton.Cursor = System.Windows.Forms.Cursors.Hand;
            this.downbutton.Font = new System.Drawing.Font("Times New Roman", 7.8F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.downbutton.Location = new System.Drawing.Point(709, 514);
            this.downbutton.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.downbutton.Name = "downbutton";
            this.downbutton.Size = new System.Drawing.Size(88, 94);
            this.downbutton.TabIndex = 1;
            this.downbutton.Text = "DOWN";
            this.downbutton.UseVisualStyleBackColor = false;
            this.downbutton.Click += new System.EventHandler(this.downbutton_Click);
            // 
            // leftbutton
            // 
            this.leftbutton.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.leftbutton.Cursor = System.Windows.Forms.Cursors.Hand;
            this.leftbutton.Font = new System.Drawing.Font("Times New Roman", 7.8F, System.Drawing.FontStyle.Bold);
            this.leftbutton.Location = new System.Drawing.Point(599, 414);
            this.leftbutton.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.leftbutton.Name = "leftbutton";
            this.leftbutton.Size = new System.Drawing.Size(88, 94);
            this.leftbutton.TabIndex = 2;
            this.leftbutton.Text = "LEFT";
            this.leftbutton.UseVisualStyleBackColor = false;
            this.leftbutton.Click += new System.EventHandler(this.leftbutton_Click);
            // 
            // upbutton
            // 
            this.upbutton.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.upbutton.Cursor = System.Windows.Forms.Cursors.Hand;
            this.upbutton.Font = new System.Drawing.Font("Times New Roman", 7.8F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.upbutton.Location = new System.Drawing.Point(709, 315);
            this.upbutton.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.upbutton.Name = "upbutton";
            this.upbutton.Size = new System.Drawing.Size(88, 94);
            this.upbutton.TabIndex = 3;
            this.upbutton.Text = "UP";
            this.upbutton.UseVisualStyleBackColor = false;
            this.upbutton.Click += new System.EventHandler(this.upbutton_Click);
            // 
            // cambutton
            // 
            this.cambutton.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.cambutton.Cursor = System.Windows.Forms.Cursors.Hand;
            this.cambutton.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.cambutton.Location = new System.Drawing.Point(52, 437);
            this.cambutton.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.cambutton.Name = "cambutton";
            this.cambutton.Size = new System.Drawing.Size(150, 62);
            this.cambutton.TabIndex = 5;
            this.cambutton.Text = "CAMERA";
            this.cambutton.UseVisualStyleBackColor = false;
            this.cambutton.Click += new System.EventHandler(this.cambutton_Click);
            // 
            // oto
            // 
            this.oto.Cursor = System.Windows.Forms.Cursors.Hand;
            this.oto.Location = new System.Drawing.Point(688, 98);
            this.oto.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.oto.Name = "oto";
            this.oto.Size = new System.Drawing.Size(116, 50);
            this.oto.TabIndex = 6;
            this.oto.Text = "OTOMATİK";
            this.oto.UseVisualStyleBackColor = true;
            this.oto.Click += new System.EventHandler(this.oto_Click);
            // 
            // manuel
            // 
            this.manuel.Cursor = System.Windows.Forms.Cursors.Hand;
            this.manuel.Location = new System.Drawing.Point(688, 221);
            this.manuel.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.manuel.Name = "manuel";
            this.manuel.Size = new System.Drawing.Size(116, 50);
            this.manuel.TabIndex = 7;
            this.manuel.Text = "MANUEL";
            this.manuel.UseVisualStyleBackColor = true;
            this.manuel.Click += new System.EventHandler(this.manuel_Click);
            // 
            // disttext
            // 
            this.disttext.Location = new System.Drawing.Point(74, 127);
            this.disttext.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.disttext.Name = "disttext";
            this.disttext.Size = new System.Drawing.Size(100, 22);
            this.disttext.TabIndex = 11;
            // 
            // verticaltext
            // 
            this.verticaltext.Location = new System.Drawing.Point(350, 128);
            this.verticaltext.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.verticaltext.Name = "verticaltext";
            this.verticaltext.Size = new System.Drawing.Size(100, 22);
            this.verticaltext.TabIndex = 12;
            // 
            // horizontaltext
            // 
            this.horizontaltext.Location = new System.Drawing.Point(224, 128);
            this.horizontaltext.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.horizontaltext.Name = "horizontaltext";
            this.horizontaltext.Size = new System.Drawing.Size(100, 22);
            this.horizontaltext.TabIndex = 13;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label2.Location = new System.Drawing.Point(74, 103);
            this.label2.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(118, 22);
            this.label2.TabIndex = 14;
            this.label2.Text = "Distance(μm)";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Font = new System.Drawing.Font("Times New Roman", 12F);
            this.label4.Location = new System.Drawing.Point(220, 103);
            this.label4.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(72, 22);
            this.label4.TabIndex = 16;
            this.label4.Text = "Vertical";
            // 
            // manueldist
            // 
            this.manueldist.Location = new System.Drawing.Point(710, 461);
            this.manueldist.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.manueldist.Name = "manueldist";
            this.manueldist.Size = new System.Drawing.Size(88, 22);
            this.manueldist.TabIndex = 17;
            // 
            // comboBox1
            // 
            this.comboBox1.FormattingEnabled = true;
            this.comboBox1.Location = new System.Drawing.Point(97, 40);
            this.comboBox1.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.comboBox1.Name = "comboBox1";
            this.comboBox1.Size = new System.Drawing.Size(146, 23);
            this.comboBox1.TabIndex = 26;
            this.comboBox1.SelectedIndexChanged += new System.EventHandler(this.comboBox1_SelectedIndexChanged);
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Font = new System.Drawing.Font("Microsoft Sans Serif", 12F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label5.Location = new System.Drawing.Point(40, 38);
            this.label5.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(53, 25);
            this.label5.TabIndex = 19;
            this.label5.Text = "Port:";
            // 
            // delaytext
            // 
            this.delaytext.Location = new System.Drawing.Point(489, 128);
            this.delaytext.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.delaytext.Name = "delaytext";
            this.delaytext.Size = new System.Drawing.Size(100, 22);
            this.delaytext.TabIndex = 20;
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Font = new System.Drawing.Font("Times New Roman", 12F);
            this.label6.Location = new System.Drawing.Point(485, 103);
            this.label6.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(95, 22);
            this.label6.TabIndex = 21;
            this.label6.Text = "Delay (μs)";
            // 
            // label7
            // 
            this.label7.AutoSize = true;
            this.label7.BackColor = System.Drawing.SystemColors.Window;
            this.label7.Font = new System.Drawing.Font("Times New Roman", 19.8F);
            this.label7.ForeColor = System.Drawing.SystemColors.ControlLightLight;
            this.label7.Location = new System.Drawing.Point(93, 222);
            this.label7.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(199, 37);
            this.label7.TabIndex = 23;
            this.label7.Text = "System Status";
            // 
            // repeatbox
            // 
            this.repeatbox.Location = new System.Drawing.Point(224, 180);
            this.repeatbox.Name = "repeatbox";
            this.repeatbox.Size = new System.Drawing.Size(100, 22);
            this.repeatbox.TabIndex = 28;
            this.repeatbox.TextChanged += new System.EventHandler(this.repeatbox_TextChanged);
            // 
            // label10
            // 
            this.label10.AutoSize = true;
            this.label10.Font = new System.Drawing.Font("Times New Roman", 12F);
            this.label10.Location = new System.Drawing.Point(220, 155);
            this.label10.Name = "label10";
            this.label10.Size = new System.Drawing.Size(65, 22);
            this.label10.TabIndex = 29;
            this.label10.Text = "Repeat";
            // 
            // speedbox
            // 
            this.speedbox.Location = new System.Drawing.Point(350, 180);
            this.speedbox.Name = "speedbox";
            this.speedbox.Size = new System.Drawing.Size(100, 22);
            this.speedbox.TabIndex = 30;
            // 
            // label11
            // 
            this.label11.AutoSize = true;
            this.label11.Font = new System.Drawing.Font("Times New Roman", 12F);
            this.label11.Location = new System.Drawing.Point(346, 155);
            this.label11.Name = "label11";
            this.label11.Size = new System.Drawing.Size(135, 22);
            this.label11.TabIndex = 31;
            this.label11.Text = "Speed (5-5000)";
            // 
            // home_button
            // 
            this.home_button.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.home_button.Cursor = System.Windows.Forms.Cursors.Hand;
            this.home_button.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Bold);
            this.home_button.Location = new System.Drawing.Point(228, 437);
            this.home_button.Name = "home_button";
            this.home_button.Size = new System.Drawing.Size(150, 62);
            this.home_button.TabIndex = 5;
            this.home_button.Text = "HOME";
            this.home_button.UseVisualStyleBackColor = false;
            this.home_button.Click += new System.EventHandler(this.home_button_Click);
            // 
            // homing
            // 
            this.homing.AutoSize = true;
            this.homing.Font = new System.Drawing.Font("Times New Roman", 19.8F);
            this.homing.ForeColor = System.Drawing.SystemColors.Window;
            this.homing.Location = new System.Drawing.Point(240, 393);
            this.homing.Name = "homing";
            this.homing.Size = new System.Drawing.Size(123, 37);
            this.homing.TabIndex = 32;
            this.homing.Text = "Homing";
            // 
            // button1
            // 
            this.button1.BackColor = System.Drawing.Color.Red;
            this.button1.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Bold);
            this.button1.ForeColor = System.Drawing.SystemColors.ActiveCaptionText;
            this.button1.Location = new System.Drawing.Point(53, 278);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(150, 62);
            this.button1.TabIndex = 33;
            this.button1.Text = "Stop";
            this.button1.UseVisualStyleBackColor = false;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // button2
            // 
            this.button2.BackColor = System.Drawing.Color.Yellow;
            this.button2.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Bold);
            this.button2.Location = new System.Drawing.Point(247, 278);
            this.button2.Name = "button2";
            this.button2.Size = new System.Drawing.Size(150, 62);
            this.button2.TabIndex = 34;
            this.button2.Text = "Finish";
            this.button2.UseVisualStyleBackColor = false;
            this.button2.Click += new System.EventHandler(this.button2_Click);
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Font = new System.Drawing.Font("Times New Roman", 12F);
            this.label3.Location = new System.Drawing.Point(346, 103);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(94, 22);
            this.label3.TabIndex = 35;
            this.label3.Text = "Horizontal";
            // 
            // label12
            // 
            this.label12.AutoSize = true;
            this.label12.Font = new System.Drawing.Font("Times New Roman", 19.8F);
            this.label12.ForeColor = System.Drawing.SystemColors.ControlLightLight;
            this.label12.Location = new System.Drawing.Point(47, 393);
            this.label12.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label12.Name = "label12";
            this.label12.Size = new System.Drawing.Size(156, 37);
            this.label12.TabIndex = 36;
            this.label12.Text = "CAMERA";
            // 
            // label8
            // 
            this.label8.AutoSize = true;
            this.label8.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label8.Location = new System.Drawing.Point(709, 438);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(118, 22);
            this.label8.TabIndex = 37;
            this.label8.Text = "Distance(μm)";
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Font = new System.Drawing.Font("Times New Roman", 19.8F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.label1.Location = new System.Drawing.Point(688, 166);
            this.label1.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(116, 37);
            this.label1.TabIndex = 38;
            this.label1.Text = "Control";
            // 
            // label
            // 
            this.label.AutoSize = true;
            this.label.Font = new System.Drawing.Font("Times New Roman", 12F);
            this.label.Location = new System.Drawing.Point(70, 155);
            this.label.Name = "label";
            this.label.Size = new System.Drawing.Size(136, 22);
            this.label.TabIndex = 40;
            this.label.Text = "Cam Delay (µs)";
            // 
            // camdelaybox
            // 
            this.camdelaybox.Location = new System.Drawing.Point(74, 180);
            this.camdelaybox.Name = "camdelaybox";
            this.camdelaybox.Size = new System.Drawing.Size(100, 22);
            this.camdelaybox.TabIndex = 41;
            // 
            // label9
            // 
            this.label9.AutoSize = true;
            this.label9.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Bold);
            this.label9.Location = new System.Drawing.Point(17, 526);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(158, 23);
            this.label9.TabIndex = 42;
            this.label9.Text = "Uygulama Notları";
            this.label9.Click += new System.EventHandler(this.label9_Click);
            // 
            // label13
            // 
            this.label13.AutoSize = true;
            this.label13.Font = new System.Drawing.Font("Times New Roman", 10.8F, System.Drawing.FontStyle.Underline, System.Drawing.GraphicsUnit.Point, ((byte)(162)));
            this.label13.Location = new System.Drawing.Point(17, 559);
            this.label13.Name = "label13";
            this.label13.Size = new System.Drawing.Size(586, 100);
            this.label13.TabIndex = 43;
            this.label13.Text = resources.GetString("label13.Text");
            // 
            // Switch_homing
            // 
            this.Switch_homing.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.Switch_homing.Cursor = System.Windows.Forms.Cursors.Hand;
            this.Switch_homing.Font = new System.Drawing.Font("Times New Roman", 12F, System.Drawing.FontStyle.Bold);
            this.Switch_homing.Location = new System.Drawing.Point(398, 437);
            this.Switch_homing.Name = "Switch_homing";
            this.Switch_homing.Size = new System.Drawing.Size(150, 62);
            this.Switch_homing.TabIndex = 44;
            this.Switch_homing.Text = "Switch Homing";
            this.Switch_homing.UseVisualStyleBackColor = false;
            this.Switch_homing.Click += new System.EventHandler(this.Switch_homing_Click);
            // 
            // label14
            // 
            this.label14.AutoSize = true;
            this.label14.Location = new System.Drawing.Point(884, 644);
            this.label14.Name = "label14";
            this.label14.Size = new System.Drawing.Size(69, 15);
            this.label14.TabIndex = 45;
            this.label14.Text = "22.04.2025";
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 15F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.AutoSize = true;
            this.BackColor = System.Drawing.SystemColors.Window;
            this.ClientSize = new System.Drawing.Size(982, 677);
            this.Controls.Add(this.label14);
            this.Controls.Add(this.Switch_homing);
            this.Controls.Add(this.label13);
            this.Controls.Add(this.label9);
            this.Controls.Add(this.camdelaybox);
            this.Controls.Add(this.label);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.label8);
            this.Controls.Add(this.label12);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.button2);
            this.Controls.Add(this.button1);
            this.Controls.Add(this.homing);
            this.Controls.Add(this.home_button);
            this.Controls.Add(this.label11);
            this.Controls.Add(this.speedbox);
            this.Controls.Add(this.label10);
            this.Controls.Add(this.repeatbox);
            this.Controls.Add(this.label7);
            this.Controls.Add(this.label6);
            this.Controls.Add(this.delaytext);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.comboBox1);
            this.Controls.Add(this.manueldist);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.horizontaltext);
            this.Controls.Add(this.verticaltext);
            this.Controls.Add(this.disttext);
            this.Controls.Add(this.manuel);
            this.Controls.Add(this.oto);
            this.Controls.Add(this.cambutton);
            this.Controls.Add(this.upbutton);
            this.Controls.Add(this.leftbutton);
            this.Controls.Add(this.downbutton);
            this.Controls.Add(this.rightbutton);
            this.Cursor = System.Windows.Forms.Cursors.Arrow;
            this.Font = new System.Drawing.Font("Times New Roman", 7.8F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Margin = new System.Windows.Forms.Padding(2, 3, 2, 3);
            this.Name = "Form1";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            this.Text = "Microscope Control App";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.Form1_FormClosing);
            this.Load += new System.EventHandler(this.Form1_Load);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Button rightbutton;
        private System.Windows.Forms.Button downbutton;
        private System.Windows.Forms.Button leftbutton;
        private System.Windows.Forms.Button upbutton;
        private System.Windows.Forms.Button cambutton;
        private System.Windows.Forms.Button oto;
        private System.Windows.Forms.Button manuel;
        private System.Windows.Forms.TextBox disttext;
        private System.Windows.Forms.TextBox verticaltext;
        private System.Windows.Forms.TextBox horizontaltext;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.TextBox manueldist;
        private System.IO.Ports.SerialPort SerialPort;
        private System.Windows.Forms.ComboBox comboBox1;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.TextBox delaytext;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.TextBox repeatbox;
        private System.Windows.Forms.Label label10;
        private System.Windows.Forms.TextBox speed;
        private System.Windows.Forms.Label label11;
        private System.Windows.Forms.Button home_button;
        private System.Windows.Forms.Label homing;
        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Button button2;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label12;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Timer timer1;
        private System.Windows.Forms.TextBox cam_delay;
        private System.Windows.Forms.Label label;
        private System.Windows.Forms.TextBox speedbox;
        private System.Windows.Forms.TextBox camdelaybox;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.Label label13;
        private System.Windows.Forms.Button Switch_homing;
        private System.Windows.Forms.Label label14;
    }
}

