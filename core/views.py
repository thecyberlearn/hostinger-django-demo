from django.shortcuts import render, redirect
from django.contrib import messages
from .models import BlogPost
from .forms import ContactForm


def home(request):
    blog_posts = BlogPost.objects.filter(is_published=True)[:3]
    return render(request, 'core/home.html', {'blog_posts': blog_posts})


def contact(request):
    if request.method == 'POST':
        form = ContactForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'Thank you for your message! We will get back to you soon.')
            return redirect('contact')
    else:
        form = ContactForm()
    
    return render(request, 'core/contact.html', {'form': form})


def blog(request):
    posts = BlogPost.objects.filter(is_published=True)
    return render(request, 'core/blog.html', {'posts': posts})


def about(request):
    return render(request, 'core/about.html')
